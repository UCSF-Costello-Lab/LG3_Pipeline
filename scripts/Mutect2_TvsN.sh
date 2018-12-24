#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}


### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=${LG3_HOME}"
  echo "- LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT}"
  echo "- LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT}"
  echo "- PWD=$PWD"
  echo "- USER=${USER}"
  echo "- PBS_NUM_PPN=${PBS_NUM_PPN}"
  echo "- hostname=$(hostname)"
  echo "- ncores=${ncores}"
	VERBOSITY=ERROR ## WARNING INFO DEBUG
else
	VERBOSITY=ERROR ## WARNING INFO DEBUG
fi
echo "- VERBOSITY=${VERBOSITY}"

### Input
nbamfile=$1
tbamfile=$2
prefix=$3
patientID=$4
ILIST=$5
XMX=$6
XMX=${XMX:-Xmx160gb} ## 160gb
PADDING=${PADDING:-0} ## Padding the intervals

HG=hg19
FUNCO_PATH=/home/GenomeData/GATK_bundle/funcotator/funcotator_dataSources.v1.4.20180615
assert_directory_exists ${FUNCO_PATH}

echo "Input:"
echo "- nbamfile=${nbamfile:?}"
echo "- tbamfile=${tbamfile:?}"
echo "- prefix=${prefix:?}"
echo "- patientID=${patientID:?}"
echo "- ILIST=${ILIST:?}"
echo "- PADDING=${PADDING:?}"
echo "- XMX=${XMX:?}"
echo "- HG=${HG:?}"
echo "- FUNCO_PATH=${FUNCO_PATH:?}"

## Assert existance of input files
assert_file_exists "${nbamfile}"
assert_file_exists "${tbamfile}"
assert_file_exists "${ILIST}"

### Software
module load jdk/1.8.0 python/2.7.15

GATK4="${LG3_HOME}/tools/gatk-4.0.12.0/gatk"
assert_file_executable "${GATK4}"

echo "Software:"
python --version
java -version

### References
REF="${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa"
echo "References:"
echo "- REF=${REF}"
assert_file_exists "${REF}"

#normalname=${nbamfile##*/}
#normalname=${normalname%%.bwa*}
#tumorname=${tbamfile##*/}
#tumorname=${tumorname%%.bwa*}

echo -e "\\n[Mutect2] Running GATK4::GetSampleName BETA!!! from ${nbamfile} ... "
{ time ${GATK4} --java-options -"${XMX}" GetSampleName \
	--verbosity "${VERBOSITY}" \
	--reference "${REF}" \
	--input "${nbamfile}" \
	--output normal_name.txt \
	-encode; } 2>&1 || { echo "FAILED"; exit 1; } 
normalname=$(cat normal_name.txt)
	
echo -e "\\n[Mutect2] Running GATK4::GetSampleName BETA!!! from ${tbamfile} ... "
{ time ${GATK4} --java-options -"${XMX}" GetSampleName \
	--verbosity "${VERBOSITY}" \
	--reference "${REF}" \
	--input "${tbamfile}" \
	--output tumor_name.txt \
	-encode; } 2>&1 || { echo "FAILED"; exit 1; } 
tumorname=$(cat tumor_name.txt)
	
rm normal_name.txt tumor_name.txt

CONTF2F=0

echo "-------------------------------------------------"
echo -n "[Mutect2] Somatic Mutation Detection "
date
echo "-------------------------------------------------"
echo "[Mutect2] Patient ID: $patientID"
echo "[Mutect2] Normal bam file: $nbamfile"
echo "[Mutect2] Tumor bam file: $tbamfile"
echo "[Mutect2] Normal Sample: $normalname"
echo "[Mutect2] Tumor Sample: $tumorname"
echo "[Mutect2] Prefix: $prefix"
echo "[Mutect2] Contamination CONTF2F: ${CONTF2F}"
echo "-------------------------------------------------"
echo "[Mutect2] Java Memory Xmx value: $XMX"
echo -n "[Mutect2] Working directory: "
pwd
echo "-------------------------------------------------"

out1=${prefix}.raw.mutect2tn.vcf.gz
out2=${prefix}.filt.mutect2tn.vcf.gz
out3=${prefix}.ann.mutect2tn.vcf

extra_args=""
[[ -z "${ILIST}" ]] || extra_args=(--intervals "${ILIST}" --interval-padding "${PADDING}")
echo "[Mutect2] extra_args: ${extra_args[*]}"

            #--af-of-alleles-not-in-resource 0.00003125 \
				#--germline-resource af-only-gnomad.vcf.gz \
if [ ! -e "${out1}" ]; then
        echo -e "\\n[Mutect2] Running GATK4::MuTect2 ..."
		  { time ${GATK4} --java-options -"${XMX}" Mutect2 "${extra_args[@]}" \
				--verbosity "${VERBOSITY}" \
            --reference "${REF}" \
            --input "${nbamfile}" \
            --normal-sample "${normalname}" \
            --input "${tbamfile}" \
            --tumor-sample "${tumorname}" \
            --contamination-fraction-to-filter ${CONTF2F} \
            --output "${out1}"; } 2>&1 || { echo "FAILED"; exit 1; }

		  assert_file_exists "${out1}"
        echo "Done"
else
        echo -e "\\n[Mutect2] Found MuTect2 output, skipping ..."
fi

echo -ne "\\n[Mutect2] Found raw somatic mutations: "
zcat "${out1}" | grep -vc '#' 

#--contamination-table contamination.table \
if [ ! -e "${out2}" ]; then
	   echo -e "\\n[GATK4] Running FilterMutectCalls ..."
   	{ time $GATK4 FilterMutectCalls "${extra_args[@]}" \
			--verbosity "${VERBOSITY}" \
      	--variant "${out1}" \
      	--output "${out2}" \
      	--reference "${REF}"; } 2>&1 || { echo "FAILED"; exit 1; }

	  	assert_file_exists "${out2}"
		echo "Done"
else
	echo -e "\\n[Mutect2] Found FilterMutectCalls output, skipping ..."
fi

if [ ! -e "${out3}" ]; then
      echo -e "\\n[GATK4] Running Funcotator ..."
      { time $GATK4 Funcotator "${extra_args[@]}" \
			--verbosity "${VERBOSITY}" \
         --variant "${out2}" \
         --output "${out3}" \
      	--output-file-format VCF \
      	--data-sources-path "${FUNCO_PATH}" \
      	--ref-version "${HG}" \
      	--transcript-selection-mode CANONICAL \
         --reference "${REF}"; } 2>&1 || { echo "FAILED"; exit 1; }
		
		assert_file_exists "${out3}"
		echo "Done"
else
   echo -e "\\n[Mutect2] Found Funcotator output, skipping ..."
fi
wc -l "${out3}"

echo -e "\\n[Mutect2] applying filter ... "
grep '^#' "${out3}" > "${out3}".tmp
grep -v '^#' "${out3}" | grep -w PASS >> "${out3}".tmp
mv "${out3}".tmp "${out3}"
wc -l "${out3}"

echo "Deleting raw calls .."
rm "${out1}" "${out1}".tbi

echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
