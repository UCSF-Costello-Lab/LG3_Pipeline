#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf
bCLEAN=true

add2fname() {
	if [ $# -ne 2 ]; then
		error "[add2fname] need exactly 2 args"
	fi
   B=$(basename "$1" .vcf.gz)
   echo "${B}.$2.vcf.gz"
}

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
ILIST=${INTERVAL:?}
XMX=$6
DEST=$7 ## Destination directory
assert_directory_exists "${DEST}"
XMX=${XMX:-Xmx160G} ## Default 160gb
PADDING=${PADDING:-0} ## Padding the intervals

bOBMM=${bOBMM:-true}
bCC=${bCC:-true}
bGNOMAD=${bGNOMAD:-true}
bFUNC=${bFUNC:-true}
echo "Flow control:"
echo "- use OBMM filter=${bOBMM:?}"
echo "- calc contamination=${bCC:?}"
echo "- use Funcotator=${bFUNC:?}"
echo "- use GNOMAD=${bGNOMAD:?}"
echo "- clean intermediate files=${bCLEAN:?}"

echo "Input:"
echo "- nbamfile=${nbamfile:?}"
echo "- tbamfile=${tbamfile:?}"
echo "- prefix=${prefix:?}"
echo "- patientID=${patientID:?}"
echo "- ILIST=${ILIST:?}"
echo "- PADDING=${PADDING:?}"
echo "- XMX=${XMX:?}"
echo "- HG=${HG:?}"

## Assert existance of input files
assert_file_exists "${nbamfile}"
assert_file_exists "${tbamfile}"
assert_file_exists "${ILIST}"

### Software
module load jdk/1.8.0 python/2.7.15 htslib/1.7

#GATK4="${LG3_HOME}/tools/gatk-4.1.0.0/gatk"
assert_file_executable "${GATK4:?}"
assert_file_executable "${LG3_HOME}"/gatk4-funcotator-vcf2tsv

echo "Software:"
python --version
#assert_python ""
java -version
echo "gatk = ${GATK4}"
echo -n "GATK4 " > GATK.ver
${GATK4} Mutect2 --help 2>&1 | grep Version >> GATK.ver

### References
assert_file_exists "${REF:?}"
echo "- reference=${REF}"

if ${bGNOMAD}; then
   echo "- GNOMAD AF =${GNOMAD}"
   assert_file_exists "${GNOMAD}"
   assert_file_exists "${GNOMAD}.tbi"
   echo "- af-of-alleles-not-in-resource=${af_of_alleles_not_in_resource:?}"
   XARG_gnomAD=(--germline-resource "${GNOMAD}" --af-of-alleles-not-in-resource "${af_of_alleles_not_in_resource}")
fi

if ${bFUNC}; then
   ### Somatic data source for Funcotator
   assert_directory_exists "${FUNCO_PATH:?}"
   echo "- FUNCO_PATH=${FUNCO_PATH}"
fi

if ${bCC}; then
	echo "- GNOMAD for contamination =${GNOMAD2:?}"
	assert_file_exists "${GNOMAD2}"
	assert_file_exists "${GNOMAD2}.tbi"
	XARG_contamination=(-V "${GNOMAD2}" -L "${GNOMAD2}")
fi

	#--reference "${REF}" \
echo -e "\\n[Mutect2] Running GATK4::GetSampleName from ${nbamfile} ... "
{ time ${GATK4} --java-options -"${XMX}" GetSampleName \
	--verbosity "${VERBOSITY}" \
	--input "${nbamfile}" \
	--output normal_name.txt \
	-encode true; } 2>&1 || error "FAILED"
normalname=$(cat normal_name.txt)
echo "Recovered normal sample name: ${normalname}"
	
echo -e "\\n[Mutect2] Running GATK4::GetSampleName from ${tbamfile} ... "
{ time ${GATK4} --java-options -"${XMX}" GetSampleName \
	--verbosity "${VERBOSITY}" \
	--input "${tbamfile}" \
	--output tumor_name.txt \
	-encode true; } 2>&1 || error "FAILED"
tumorname=$(cat tumor_name.txt)
echo "Recovered tumor sample name: ${tumorname}"
	
if ${bOBMM}; then
   XARG_OBMM=(--f1r2-tar-gz "${tumorname}-F1R2Counts.tar.gz")
fi

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
echo "[Mutect2] Known contamination CONTF2F: ${CONTF2F}"
echo "-------------------------------------------------"
echo "[Mutect2] Java Memory Xmx value: $XMX"
echo -n "[Mutect2] Working directory: "
pwd
echo "-------------------------------------------------"

OUT=${prefix}.vcf.gz ## Initial output name


OUT=$(add2fname "${OUT}" m2)
extra_args=""
[[ -z "${INTERVAL}" ]] || extra_args=(--intervals "${INTERVAL}" --interval-padding "${PADDING}")
echo "[Mutect2] extra_args: ${extra_args[*]}"

echo -e "\\n[Mutect2] Running GATK4::MuTect2 ..."
      { time ${GATK4} --java-options -"${XMX}" Mutect2 "${extra_args[@]}" "${XARG_gnomAD[@]}" ${XARG_OBMM[@]}\
            --verbosity "${VERBOSITY}" \
            --reference "${REF}" \
            --input "${nbamfile}" \
            --normal "${normalname}" \
            --input "${tbamfile}" \
            --output "${OUT}"; } 2>&1 || error "FAILED"
        echo "Done"
mv "${OUT}.stats" "${tumorname}-M2FilteringStats.tsv"

assert_file_exists "${OUT}"
assert_file_exists "${OUT}".tbi
assert_file_exists "${tumorname}-M2FilteringStats.tsv"
echo -ne "\\n[Mutect2] Found raw somatic mutations in ${OUT}: "
zcat "${OUT}" | grep -vc '^#'
IN=${OUT}


if ${bOBMM}; then
	echo -e "\\n[Mutect2] OBMM filter is requested. Collecting some metrics..."
   OUT=$(add2fname "${OUT}" obmm)
   assert_file_exists "${tumorname}-F1R2Counts.tar.gz"

   ### Learning step of the OB MM filter (RECOMMENDED)
   ### AKA read orientation model
   ### Get the maximum likelihood estimates of artifact prior probabilities
   echo -e "\\n[Mutect2] Running GATK4::LearnReadOrientationModel ..."
   { time ${GATK4} --java-options -"${XMX}" LearnReadOrientationModel \
      --verbosity "${VERBOSITY}" \
      -I "${tumorname}-F1R2Counts.tar.gz" \
      -O "${tumorname}-artifact-prior-table.tar.gz"; } 2>&1 || error "FAILED"

   assert_file_exists "${tumorname}-artifact-prior-table.tar.gz"
   echo "[Mutect2] Generated artifact priors:"
   ls -l "${tumorname}-artifact-prior-table.tar.gz"

   XARG_artifact_prior=(--orientation-bias-artifact-priors "${tumorname}-artifact-prior-table.tar.gz")
else
   echo "OBMM filter not requested"
fi

if ${bCC}; then
	OUT=$(add2fname "${OUT}" cc)
	echo -e "\\n\\n[Mutect2] Calculate Contamination is requested ..."
	

   #GNOMAD2=/home/GenomeData/gnomAD_hg19/mutect2/mutect2-contamination-var.biall.vcf.gz
   echo "- GNOMAD for contamination =${GNOMAD2:?}"
   assert_file_exists "${GNOMAD2}"
   assert_file_exists "${GNOMAD2}.tbi"
   XARG_contamination=(-V "${GNOMAD2}" -L "${GNOMAD2}")
   #XARG_contamination=(-L "${GNOMAD2}")


	### Tabulates pileup metrics for inferring contamination
	echo -e "\\n[Mutect2] Running GATK4::GetPileupSummaries for Normal ..."
	{ time ${GATK4} --java-options -"${XMX}" GetPileupSummaries "${XARG_contamination[@]}" \
		--verbosity "${VERBOSITY}" \
		-I "${nbamfile}" \
		--interval-set-rule INTERSECTION \
		-O "${tumorname}-normal_pileups.table"; } 2>&1 || error "FAILED"	
	
	assert_file_exists "${tumorname}-normal_pileups.table"
	echo "Generated pileups:"
	wc -l "${tumorname}-normal_pileups.table"
	
	echo -e "\\n[Mutect2] Running GATK4::GetPileupSummaries for Tumor ..."
	{ time ${GATK4} --java-options -"${XMX}" GetPileupSummaries "${XARG_contamination[@]}" \
		--verbosity "${VERBOSITY}" \
		-R "${REF}" \
		-I "${tbamfile}" \
		--interval-set-rule INTERSECTION \
		-O "${tumorname}-pileups.table"; } 2>&1 || error "FAILED"	

	assert_file_exists "${tumorname}-pileups.table"
	echo "[Mutect2] Generated pileups:"
	wc -l "${tumorname}-pileups.table"
	
	### Calculate the fraction of reads coming from cross-sample contamination
	echo -e "\\n[Mutect2] Running GATK4::CalculateContamination ..."
	{ time ${GATK4} --java-options -"${XMX}" CalculateContamination \
		--verbosity "${VERBOSITY}" \
		-I "${tumorname}-pileups.table" \
		-O "${tumorname}-contamination.table" \
		--tumor-segmentation "${tumorname}-segments.table" \
		--matched-normal "${tumorname}-normal_pileups.table"; } 2>&1 || error "FAILED" 
	
	echo "[Mutect2] Generated contamination and segments tables:"
	assert_file_exists "${tumorname}-contamination.table"
	assert_file_exists "${tumorname}-segments.table"

	wc -l "${tumorname}-contamination.table"
	cat "${tumorname}-contamination.table"
	wc -l "${tumorname}-segments.table"
	
	XARG_contamination_filter=(--contamination-table "${tumorname}-contamination.table" --tumor-segmentation "${tumorname}-segments.table")
else
	echo -e "\\n\\n[Mutect2] Calculate Contamination is NOT requested. Skipping ..."	
	XARG_contamination_filter=()
fi

### Filter somatic SNVs and indels called by Mutect2
### Use always with optional contamination and segments tables!
#${m2_extra_filtering_args} optional
### --f-score-beta 1.0 [def], >1 to increase sensitivity! <1 to increase precision

echo -e "\\n[Mutect2] Running FilterMutectCalls ..."
OUT=$(add2fname "${OUT}" flt)

{ time ${GATK4} FilterMutectCalls "${extra_args[@]}" "${XARG_contamination_filter[@]}" "${XARG_artifact_prior[@]}" \
			--verbosity "${VERBOSITY}" \
      	--variant "${IN}" \
      	--output "${OUT}" \
			--stats "${tumorname}-M2FilteringStats.tsv" \
			--contamination-estimate ${CONTF2F} \
         --threshold-strategy OPTIMAL_F_SCORE \
         --f-score-beta 1.0 \
      	--reference "${REF}"; } 2>&1 || error "FAILED"
		echo "Done"
assert_file_exists "${OUT}"

echo -n "[Mutect2] Total mutations in ${OUT}: "
zcat "${OUT}" | grep -vc '^#'
echo -n "[Mutect2] PASSed FilterMutectCalls: "
zcat "${OUT}" | grep -v '^#' | grep -wc PASS 
IN=${OUT}


if ${bFUNC}; then
	OUT=$(add2fname "${OUT}" func)
	echo -e "\\n[Mutect2] Funcotator annotations requested ..."
	### A GATK functional annotation tool.
   echo -e "\\n[Mutect2] Running Funcotator ..."
   { time ${GATK4} Funcotator "${extra_args[@]}" \
		--verbosity ERROR \
      --variant "${IN}" \
      --output "${OUT}" \
     	--output-file-format VCF \
     	--data-sources-path "${FUNCO_PATH}" \
     	--ref-version "${HG}" \
     	--transcript-selection-mode CANONICAL \
      --reference "${REF}"; } 2>&1 || warn "FAILED"
	echo "Done"
	assert_file_exists "${OUT}"

   echo -n "[Mutect2] Total mutations in ${OUT}: "
   zcat "${OUT}" | grep -vc '^#'
   echo -n "[Mutect2] PASSed all filters: "
   zcat "${OUT}" | grep -v '^#' | grep -wc PASS
   IN=${OUT}
else
	echo -e "\\nFuncotator annotations are NOT requested. Skipping ..."
fi


OUT=$(add2fname "${OUT}" filt)

echo -e "\\n[Mutect2] Keep only PASSed variants ... "
zcat "${IN}" | grep '^#' | bgzip > "${OUT}"
zcat "${IN}" | grep -v '^#' | grep -w PASS | bgzip >> "${OUT}"

echo -e "\\n[Mutect2] Indexing ${OUT} ..."
tabix -p vcf "${OUT}" || error "FAILED"

echo -n "[Mutect2] Total mutations in ${OUT}: "
zcat "${OUT}" | grep -vc '^#'
echo -n "[Mutect2] PASSed all filters: "
zcat "${OUT}" | grep -v '^#' | grep -wc PASS

echo "[Mutect2] Extracting selected Funcotator annotations in .tsv format"
"${LG3_HOME}"/gatk4-funcotator-vcf2tsv "${OUT}"


if ${bCLEAN}; then
   echo "Cleaning intermediate files"
   rm -f "${tumorname}-M2FilteringStats.tsv"
   rm -f "${tumorname}-F1R2Counts.tar.gz"
   rm -f "${tumorname}-artifact-prior-table.tar.gz"
   rm -f "${tumorname}-normal_pileups.table"
   rm -f "${tumorname}-pileups.table"
   rm -f "${tumorname}-segments.table"
fi

echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
