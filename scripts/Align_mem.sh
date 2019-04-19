#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf
XMX=${XMX:-Xmx32G} 

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"
CLEAN=true

# shellcheck source=scripts/config.sh
source "${LG3_HOME}/scripts/config.sh"

LG3_CHASTITY_FILTERING=${LG3_CHASTITY_FILTERING:-true}
assert_file_exists "${INTERVAL:?}"

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
  echo "- hostname=$(hostname)"
  echo "- ncores=$ncores"
  echo "- LG3_CHASTITY_FILTERING=${LG3_CHASTITY_FILTERING:-?}"
  echo "- CLEAN=${CLEAN}"
  echo "- INTERVAL=${INTERVAL:?}"
  echo "- PADDING=${PADDING:?}"
fi

BWA_INDEX_HOME=$(dirname "${BWA_INDEX}")
assert_directory_exists "${BWA_INDEX_HOME}"
assert_file_exists "${REF:?}"
assert_file_exists "${DBSNP:?}"
assert_file_exists "${THOUSAND:?}"
echo "Resources:"
echo "- BWA_INDEX=${BWA_INDEX}"
echo "- reference=${REF}"
echo "- DBSNP=${DBSNP}"
echo "- THOUSAND=${THOUSAND}"

## Software

PYTHON=/usr/bin/python
unset PYTHONPATH  ## ADHOC: In case it is set by user. /HB 2018-09-07

module load jdk/1.8.0 python/2.7.15 htslib/1.7 bwa/0.7.17 samtools/1.7

JAVA=java
BWA=bwa
SAMTOOLS=samtools
assert_file_executable "${GATK4}"
PYTHON_REMOVEQC_GZ=${LG3_HOME}/scripts/removeQCgz.py

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- PYTHON=${PYTHON:?}"
echo "- BWA=${BWA:?}"
echo "- SAMTOOLS=${SAMTOOLS:?}"

## Assert existance of software
assert_file_executable "${PYTHON}"
assert_file_executable "$(which ${BWA})"
assert_file_exists "${PYTHON_REMOVEQC_GZ}"

### Input
pl="Illumina"
pu="Exome"
fastq1=$1
fastq2=$2
SAMPLE=$3
echo "Input:"
echo "- fastq1=${fastq1:?}"
echo "- fastq2=${fastq2:?}"
echo "- SAMPLE=${SAMPLE:?}"
echo "- pl=${pl:?} (hard coded)"
echo "- pu=${pu:?} (hard coded)"

## Assert existance of input files
assert_file_exists "${fastq1}"
assert_file_exists "${fastq2}"


TMP="${LG3_SCRATCH_ROOT}/$SAMPLE/tmp"
make_dir "${TMP}"

echo "-------------------------------------------------"
echo "[Align] BWA alignment!"
echo "-------------------------------------------------"
echo "[Align] Fastq file #1: $fastq1"
echo "[Align] Fastq file #2: $fastq2"
echo "[Align] Prefix: $SAMPLE"
echo "[Align] BWA index: $BWA_INDEX"
echo "-------------------------------------------------"


if [[ "${LG3_CHASTITY_FILTERING}" == "true" ]]; then
  echo "[Align] Removing chastity filtered first-in-pair reads..."
  $PYTHON "${PYTHON_REMOVEQC_GZ}" "$fastq1" \
          > "${SAMPLE}.read1.QC.fastq" || error "Chastity filtering read1 failed"
	assert_file_exists "${SAMPLE}.read1.QC.fastq"

  echo "[Align] Removing chastity filtered second-in-pair reads..."
  $PYTHON "${PYTHON_REMOVEQC_GZ}" "$fastq2" \
          > "${SAMPLE}.read2.QC.fastq" || error "Chastity filtering read2 failed"
	assert_file_exists "${SAMPLE}.read2.QC.fastq"
else
  echo "[Align] Skipping chastity filter (faked by a verbatim copy) ..."
  zcat "$fastq1" > "${SAMPLE}.read1.QC.fastq"
  assert_file_exists "${SAMPLE}.read1.QC.fastq"
  zcat "$fastq2" > "${SAMPLE}.read2.QC.fastq"
  assert_file_exists "${SAMPLE}.read2.QC.fastq"
fi

### BWA mem Alignment
### -M for Picard compatibility
echo "[Align] bwa mem ... "
## bwa mem -K 100000000 -p -v 3 -t 16 -Y ref_fasta
{ time $BWA mem -M -t "${ncores}" -R "@RG\\tID:${SAMPLE}\\tSM:${SAMPLE}\\tPL:$pl\\tLB:${SAMPLE}\\tPU:$pu" "$BWA_INDEX" "${SAMPLE}.read1.QC.fastq" "${SAMPLE}.read2.QC.fastq" > "${SAMPLE}.mem.sam" 2>> __"${SAMPLE}.mem.log"; } 2>&1 || { cat __"${SAMPLE}.mem.log";  error "FAILED"; }

assert_file_exists "${SAMPLE}.mem.sam"
${CLEAN} && rm -f "${SAMPLE}"_R?.fastq
${CLEAN} && rm -f __"${SAMPLE}".mem.log
${CLEAN} && rm -f "${SAMPLE}".read?.QC.fastq

echo "[Align] GATK4::SortSam "
{ time ${GATK4} --java-options -"${XMX}" SortSam \
   --INPUT "${SAMPLE}.mem.sam" \
   --OUTPUT  "${SAMPLE}.mem.sorted.bam" \
   --SORT_ORDER "coordinate" \
   --CREATE_INDEX false \
	--QUIET true; } 2>&1 || error "FAILED"

assert_file_exists "${SAMPLE}.mem.sorted.bam"
${CLEAN} && rm -f "${SAMPLE}.mem.sam"
	
echo "[Align] GATK4::SetNmMdAndUqTags"
{ time ${GATK4} --java-options -"${XMX}" SetNmMdAndUqTags \
   --INPUT "${SAMPLE}.mem.sorted.bam" \
   --OUTPUT "${SAMPLE}.mem.sorted.tagged.bam" \
	--CREATE_INDEX false \
	-R "${REF}" \
   --QUIET true; } 2>&1 || error "FAILED"

assert_file_exists "${SAMPLE}.mem.sorted.tagged.bam"
echo "Renaming ${SAMPLE}.mem.sorted.tagged.bam --> ${SAMPLE}.mem.sorted.bam"
mv "${SAMPLE}.mem.sorted.tagged.bam" "${SAMPLE}.mem.sorted.bam"

echo "[Align] GATK4::MarkDuplicates "
##--OPTICAL_DUPLICATE_PIXEL_DISTANCE 2500 - for patterned flowcell models [default 100 for unpatterned]
{ time ${GATK4} --java-options -"${XMX}" MarkDuplicates \
	--INPUT "${SAMPLE}.mem.sorted.bam" \
	--OUTPUT "${SAMPLE}.mem.sorted.mrkDups.bam" \
	--METRICS_FILE "${SAMPLE}.mem.sorted.mrkDups.metrics" \
	--VALIDATION_STRINGENCY SILENT \
	--OPTICAL_DUPLICATE_PIXEL_DISTANCE 2500 \
	--REMOVE_DUPLICATES false \
	--REMOVE_SEQUENCING_DUPLICATES false \
	--ASSUME_SORT_ORDER "queryname" \
	--CREATE_INDEX true \
	--QUIET true \
   --VERBOSITY ERROR; } 2>&1 || error "FAILED"
wc -l "${SAMPLE}.mem.sorted.mrkDups.metrics"

echo "[Align] Index ${SAMPLE}.mem.sorted.mrkDups.bam"
{ time ${SAMTOOLS} index "${SAMPLE}.mem.sorted.mrkDups.bam"; } 2>&1 || error "FAILED"

echo "[QC] Flagstat after MarkDuplicates"
{ time ${SAMTOOLS} flagstat "${SAMPLE}.mem.sorted.mrkDups.bam" > "${SAMPLE}.mem.sorted.mrkDups.flagstat"; } 2>&1 || error "FAILED"

assert_file_exists "${SAMPLE}.mem.sorted.mrkDups.flagstat"
cat "${SAMPLE}.mem.sorted.mrkDups.flagstat"

echo "[BQSR] GATK4::BaseRecalibrator "
{ time ${GATK4} --java-options -"${XMX}" BaseRecalibrator \
   --input "${SAMPLE}.mem.sorted.mrkDups.bam" \
	--output "${SAMPLE}.mem.sorted.mrkDups.recal.table" \
	-R "${REF}" \
	--use-original-qualities true \
	--known-sites "${DBSNP}" \
	--known-sites "${THOUSAND}" \
	--intervals "${INTERVAL:?}" \
	--interval-padding "${PADDING:?}" \
	--create-output-bam-index true \
   --QUIET true \
   --verbosity ERROR; } 2>&1 || error "FAILED"
echo "Output: "
wc -l "${SAMPLE}.mem.sorted.mrkDups.recal.table"

echo "[BQSR] GATK4::ApplyBQSR "
{ time ${GATK4} --java-options -"${XMX}" ApplyBQSR \
	--input "${SAMPLE}.mem.sorted.mrkDups.bam" \
	--bqsr-recal-file "${SAMPLE}.mem.sorted.mrkDups.recal.table" \
	--output "${SAMPLE}.mem.sorted.mrkDups.recal.bam" \
	-R "${REF}" \
	--static-quantized-quals 10 --static-quantized-quals 20 --static-quantized-quals 30 \
	--add-output-sam-program-record \
	--use-original-qualities \
   --intervals "${INTERVAL:?}" \
   --interval-padding "${PADDING:?}" \
	--create-output-bam-index true \
   --QUIET true \
   --verbosity ERROR; } 2>&1 || error "FAILED"
		
echo "[Align] Index ${SAMPLE}.mem.sorted.mrkDups.recal.bam"
{ time ${SAMTOOLS} index "${SAMPLE}.mem.sorted.mrkDups.recal.bam"; } 2>&1 || error "FAILED"

echo "[QC] GATK4::CollectHsMetrics "
{ time ${GATK4} --java-options -"${XMX}" CollectHsMetrics \
	--INPUT "${SAMPLE}.mem.sorted.mrkDups.recal.bam" \
	--OUTPUT "${SAMPLE}.mem.sorted.mrkDups.recal.HS_metrics" \
   --BAIT_INTERVALS "${INTERVAL:?}" \
   --TARGET_INTERVALS "${INTERVAL:?}" \
   --QUIET true \
   --VERBOSITY ERROR; } 2>&1 || error "FAILED"

echo "Ouput "
wc -l "${SAMPLE}.mem.sorted.mrkDups.recal.HS_metrics"

echo "[QC] GATK4::CollectMultipleMetrics "
{ time ${GATK4} --java-options -"${XMX}" CollectMultipleMetrics \
   --INPUT  "${SAMPLE}.mem.sorted.mrkDups.recal.bam" \
   --OUTPUT "${SAMPLE}.mem.sorted.mrkDups.recal.multi_metrics" \
   --QUIET true \
   --VERBOSITY ERROR; } 2>&1 || error "FAILED"

echo "Ouput "
wc -l "${SAMPLE}.mem.sorted.mrkDups.recal.multi_metrics"*

${CLEAN} && rm -f "${SAMPLE}.mem.sorted."???
${CLEAN} && rm -f "${SAMPLE}.mem.sorted.mrkDups.bam"
${CLEAN} && rm -f "${SAMPLE}.mem.sorted.mrkDups.bam.bai"

echo "All done!"
echo "-------------------------------------------------"
rm -rf "$TMP"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
