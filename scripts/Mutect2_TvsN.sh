#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf
CLEAN=true

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

HG=hg19

bOBMM=${bOBMM:-true}
bCC=${bCC:-true}
bOB=${bOB:-false}
bAA=${bAA:-false}
bFUNC=${bFUNC:-true}
echo "Flow control:"
echo "- use OBMM filter=${bOBMM:?}"
echo "- calc contamination=${bCC:?}"
echo "- use OB filter=${bOB:?}"
echo "- use AA filter=${bAA:?}"
echo "- use Funcotator=${bFUNC:?}"
echo "- clean intermediate files=${CLEAN:?}"

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
java -version

assert_python ""

### References
assert_file_exists "${REF:?}"
echo "- reference=${REF}"

### Somatic data source for Funcotator
assert_directory_exists "${FUNCO_PATH:?}"
echo "- FUNCO_PATH=${FUNCO_PATH}"

if ${bAA}; then
	IMG="${REF}.img"
	assert_file_exists "${IMG}"
	echo "- BWA image =${IMG}"
fi

#GNOMAD=/home/GenomeData/GATK_bundle/Mutect2/af-only-gnomad.raw.sites.hg19.vcf.gz
#GNOMAD=/home/GenomeData/gnomAD_hg19/mutect2/gnomad4mutect2.vcf.gz
### Population allele fraction assigned to alleles not found in germline resource.
### See docs/mutect/mutect2.pdf for derivation of default value.
### af-of-alleles-not-in-resource == 1(2*N.of.samples in GNOMAD) 
### Default 0.001 if there is no population germline resource; 
### If Gnomad 125,748 exomes ==> 0.000004

[[ -z "${GNOMAD}" ]] || {
	echo "- GNOMAD AF =${GNOMAD}"
	assert_file_exists "${GNOMAD}"
	assert_file_exists "${GNOMAD}.tbi"
	#af_of_alleles_not_in_resource=0.000004
	echo "- af-of-alleles-not-in-resource=${af_of_alleles_not_in_resource:?}"
	XARG_gnomAD=(--germline-resource "${GNOMAD}" --af-of-alleles-not-in-resource "${af_of_alleles_not_in_resource}")
}

#GNOMAD2=/home/GenomeData/gnomAD_hg19/mutect2/mutect2-contamination-var.biall.vcf.gz
if ${bCC}; then
	echo "- GNOMAD for contamination =${GNOMAD2:?}"
	assert_file_exists "${GNOMAD2}"
	assert_file_exists "${GNOMAD2}.tbi"
	XARG_contamination=(-V "${GNOMAD2}" -L "${GNOMAD2}")
fi

#normalname=${nbamfile##*/}
#normalname=${normalname%%.bwa*}
#tumorname=${tbamfile##*/}
#tumorname=${tumorname%%.bwa*}

	#--reference "${REF}" \
echo -e "\\n[Mutect2] Running GATK4::GetSampleName (BETA) from ${nbamfile} ... "
{ time ${GATK4} --java-options -"${XMX}" GetSampleName \
	--verbosity "${VERBOSITY}" \
	--input "${nbamfile}" \
	--output normal_name.txt \
	-encode true; } 2>&1 || error "FAILED"
normalname=$(cat normal_name.txt)
echo "Recovered normal sample name: ${normalname}"
	
echo -e "\\n[Mutect2] Running GATK4::GetSampleName (BETA) from ${tbamfile} ... "
{ time ${GATK4} --java-options -"${XMX}" GetSampleName \
	--verbosity "${VERBOSITY}" \
	--input "${tbamfile}" \
	--output tumor_name.txt \
	-encode true; } 2>&1 || error "FAILED"
tumorname=$(cat tumor_name.txt)
echo "Recovered tumor sample name: ${tumorname}"
	
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

if ${bOBMM}; then
	echo -e "\\n[Mutect2] OBMM filter is requested. Collecting some metrics..."
	### Collect F1R2 read counts for the Mutect2 Orientation Bias Mixture Model filter
	### Needed for OB MM filter, which is RECOMMENDED as of Sep 2018!
	echo -e "\\n[Mutect2] Running GATK4::CollectF1R2Counts ..."
	{ time ${GATK4} --java-options -"${XMX}" CollectF1R2Counts "${extra_args[@]}" \
		--verbosity "${VERBOSITY}" \
		-I "${tbamfile}" \
		-R "${REF}" \
		-O "${tumorname}-F1R2Counts.tar.gz"; } 2>&1 || error "FAILED"
	
	assert_file_exists "${tumorname}-F1R2Counts.tar.gz"
	echo "[Mutect2] Generated metrics:"
	ls -l "${tumorname}-F1R2Counts.tar.gz"
	
	### Learning step of the OB MM filter (RECOMMENDED)
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
	echo -e "\\n[Mutect2] OBMM filter is NOT requested. Skipping ..."
fi

OUT=$(add2fname "${OUT}" m2)
if ${bOBMM}; then
   OUT=$(add2fname "${OUT}" obmm)
fi
extra_args=""
[[ -z "${ILIST}" ]] || extra_args=(--intervals "${ILIST}" --interval-padding "${PADDING}")
echo "[Mutect2] extra_args: ${extra_args[*]}"

### --disable-read-filter MateOnSameContigOrNoMappedMateReadFilter when use alt-aware and post-alt processed alignments to GRCh38
if [ ! -e "${DEST}/${OUT}" ]; then
      echo -e "\\n[Mutect2] Running GATK4::MuTect2 ..."
		if ${bAA}; then
			 XARG_bamout=(--bam-output "${tumorname}".bamout.bam)
			echo "[Mutect2] BAM out option requested"
			echo "${XARG_bamout[@]}"
		fi
		{ time ${GATK4} --java-options -"${XMX}" Mutect2 "${extra_args[@]}" "${XARG_bamout[@]}"  "${XARG_gnomAD[@]}" \
				--verbosity "${VERBOSITY}" \
            --reference "${REF}" \
            --input "${nbamfile}" \
            --normal-sample "${normalname}" \
            --input "${tbamfile}" \
            --tumor-sample "${tumorname}" \
            --output "${OUT}"; } 2>&1 || error "FAILED"
        echo "Done"
			mv "${OUT}.stats" "${tumorname}-M2FilteringStats.tsv"
		
else
      echo -e "\\n[Mutect2] Found MuTect2 output ${OUT}, downloading ..."
		cp -p "${DEST}/${OUT}" .
		cp -p "${DEST}/${OUT}.tbi" .
		if ${bAA}; then
			cp -p "${DEST}/${tumorname}.bamout.bam" .
			cp -p "${DEST}/${tumorname}.bamout.bai" .	
		fi
fi
assert_file_exists "${OUT}"
assert_file_exists "${OUT}".tbi
assert_file_exists "${tumorname}-M2FilteringStats.tsv"
if ${bAA}; then
	assert_file_exists "${tumorname}".bamout.bam
	assert_file_exists "${tumorname}".bamout.bai
fi

echo -ne "\\n[Mutect2] Found raw somatic mutations in ${OUT}: "
zcat "${OUT}" | grep -vc '^#' 
IN=${OUT}


if ${bCC}; then
	OUT=$(add2fname "${OUT}" cc)
	echo -e "\\n\\n[Mutect2] Calculate Contamination is requested ..."
	
	### Tabulates pileup metrics for inferring contamination
	echo -e "\\n[Mutect2] Running GATK4::GetPileupSummaries (BETA!) for Normal ..."
	{ time ${GATK4} --java-options -"${XMX}" GetPileupSummaries "${XARG_contamination[@]}" \
		--verbosity "${VERBOSITY}" \
		-I "${nbamfile}" \
		--interval-set-rule INTERSECTION \
		-O "${tumorname}-normal_pileups.table"; } 2>&1 || error "FAILED"	
	
	assert_file_exists "${tumorname}-normal_pileups.table"
	echo "Generated pileups:"
	wc -l "${tumorname}-normal_pileups.table"
	
	echo -e "\\n[Mutect2] Running GATK4::GetPileupSummaries (BETA!) for Tumor ..."
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
## --reference "${REF}" # Optional
#${m2_extra_filtering_args} optional
if [ ! -e "${DEST}/${OUT}" ]; then
	   echo -e "\\n[Mutect2] Running FilterMutectCalls ..."
   	{ time ${GATK4} FilterMutectCalls "${extra_args[@]}" "${XARG_contamination_filter[@]}" "${XARG_artifact_prior[@]}" \
			--verbosity "${VERBOSITY}" \
      	--variant "${IN}" \
      	--output "${OUT}" \
			--stats "${tumorname}-M2FilteringStats.tsv" \
			--contamination-estimate ${CONTF2F} \
      	--reference "${REF}"; } 2>&1 || error "FAILED"
		echo "Done"
else
	echo -e "\\n[Mutect2] Found FilterMutectCalls output ${OUT}, downloading ..."
	cp -p "${DEST}/${OUT}" .
fi
assert_file_exists "${OUT}"

echo -n "[Mutect2] Total mutations in ${OUT}: "
zcat "${OUT}" | grep -vc '^#'
echo -n "[Mutect2] PASSed FilterMutectCalls: "
zcat "${OUT}" | grep -v '^#' | grep -wc PASS 
IN=${OUT}


if ${bOB}; then
	OUT=$(add2fname "${OUT}" ob)	
	echo -e "\\n[Mutect2] OrientationBias (OB) filter is requested [deprecated!]... "
	### Collect metrics to quantify single-base sequencing artifacts
	### both pre-adapter and bait-bias
	### Needed for OB filter only: FilterByOrientationBias
	echo -e "\\n[Mutect2] Running GATK4::CollectSequencingArtifactMetrics ..."
	{ time ${GATK4} --java-options -"${XMX}" CollectSequencingArtifactMetrics \
		--VERBOSITY "${VERBOSITY}" \
		-I "${tbamfile}" \
		-R "${REF}" \
		--FILE_EXTENSION ".txt" \
		-VALIDATION_STRINGENCY LENIENT \
		-O "${tumorname}"-artifact; } 2>&1 || error "FAILED"
	
	pre_adapter_metrics=${tumorname}-artifact.pre_adapter_detail_metrics.txt
	assert_file_exists "${pre_adapter_metrics}"
	assert_file_exists "${tumorname}"-artifact.pre_adapter_summary_metrics.txt
	assert_file_exists "${tumorname}"-artifact.error_summary_metrics.txt
	assert_file_exists "${tumorname}"-artifact.bait_bias_summary_metrics.txt
	assert_file_exists "${tumorname}"-artifact.bait_bias_detail_metrics.txt
	
	echo "[Mutect2] Generated various artifact metrics:"
	wc -l "${tumorname}-artifact."*
	
	### Filter Mutect2 somatic variant calls using the OB Filter.
	### GATK implementation of D-ToxoG with modifications to allow 
	### multiple artifact modes
	### Not recommended! Use OB MM filter instead
	### https://software.broadinstitute.org/cancer/cga/dtoxog
	### Used for the OxoG (G/T) and Deamination (FFPE) (C/T) artifacts .
	# -AM ${sep=" -AM " final_artifact_modes} \
	if [ ! -e "${DEST}/${OUT}" ]; then
      	echo -e "\\n[Mutect2] Running FilterByOrientationBias **EXPERIMENTAL** ..."
				{ time ${GATK4} FilterByOrientationBias \
				--verbosity "${VERBOSITY}" \
				-V "${IN}" \
				--artifact-modes 'G/T' \
				-P "${pre_adapter_metrics}" \
				-O "${OUT}"; } 2>&1 || error "FAILED" 
      	echo "Done"
	else
   	echo -e "\\n[Mutect2] Found FilterByOrientationBias output ${OUT}, downloading ..."
		cp -p "${DEST}/${OUT}" .
	fi
	assert_file_exists "${OUT}"

	echo -n "[Mutect2] Total mutations in ${OUT}: "
	zcat "${OUT}" | grep -vc '^#'
	echo -n "[Mutect2] PASSed FilterByOrientationBias: "
	zcat "${OUT}" | grep -v '^#' | grep -wc PASS
	IN=${OUT}
else
	echo -e "\\n[Mutect2] OB filter is NOT requested. Skipping ... "
fi


if ${bAA}; then
	OUT=$(add2fname "${OUT}" aa)	
	echo -e "\\n[Mutect2] AlignmentArtifacts (AA) filter is requested ..."

	### Filter alignment artifacts from a vcf callset.
	## --bwa-mem-index-image  Generated by BwaMemIndexImageCreator.
	if [ ! -e "${DEST}/${OUT}" ]; then
      	echo -e "\\n[Mutect2] Running FilterAlignmentArtifacts **EXPERIMENTAL** ..."
      	{ time ${GATK4} FilterAlignmentArtifacts \
			--verbosity "${VERBOSITY}" \
			-V "${IN}" \
			-I "${tumorname}".bamout.bam \
			--bwa-mem-index-image "${IMG}" \
			--output "${OUT}" \
      	--reference "${REF}"; } 2>&1 || error "FAILED"
	
      	echo "Done"
	else
		echo -e "\\n[Mutect2] Found FilterAlignmentArtifacts output ${OUT}, downloading ..."
		cp -p "${DEST}/${OUT}" .
		cp -p "${DEST}/${OUT}".tbi .
	fi

   assert_file_exists "${OUT}"
	
	echo -ne "\\n[Mutect2] Total mutations in ${OUT}: "
	zcat "${OUT}" | grep -vc '^#'
	echo -ne "\\n[Mutect2] PASSed FilterAlignmentArtifacts: "
	zcat "${OUT}" | grep -v '^#' | grep -wc PASS
	IN=${OUT}
else
	echo -e "\\n[Mutect2] AlignmentArtifacts filter is NOT requested. Skipping ..."
fi

if ${bFUNC}; then
	OUT=$(add2fname "${OUT}" func)
	echo -e "\\n[Mutect2] Funcotator annotations requested ..."
			#--verbosity "${VERBOSITY}" \
	### A GATK functional annotation tool.
	if [ ! -e "${DEST}/${OUT}" ]; then
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
	else
   	echo -e "\\n[Mutect2] Found Funcotator output ${OUT}, downloading ..."
		cp -p "${DEST}/${OUT}" .
		cp -p "${DEST}/${OUT}".tbi .
	fi
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

echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
