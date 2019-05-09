#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}

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
fi

#
##
### Align Illumina PE exome sequence data from two fastq files with BWA.
###
### /path/to/Align_fastq.sh <fastq1> <fastq2> <output SAMPLE>
##
#

## References
echo "References:"
echo "- BWA_INDEX_OLD=${BWA_INDEX_OLD:?}"
BWA_INDEX_HOME=$(dirname "${BWA_INDEX_OLD}")
assert_directory_exists "${BWA_INDEX_HOME}"

## Software
PYTHON=/usr/bin/python
unset PYTHONPATH  ## ADHOC: In case it is set by user. /HB 2018-09-07

PYTHON_REMOVEQC_GZ=${LG3_HOME}/scripts/removeQCgz.py
PICARD_FIXMATEINFO=${LG3_HOME}/tools/picard-tools-1.64/FixMateInformation.jar
PICARD_ADD_OR_REPLACE_RG=${LG3_HOME}/tools/picard-tools-1.64/AddOrReplaceReadGroups.jar

echo "Software:"
echo "- JAVA6=${JAVA6:?}"
echo "- PYTHON=${PYTHON:?}"
echo "- BWA_OLD=${BWA_OLD:?}"
echo "- SAMTOOLS0_1_18=${SAMTOOLS0_1_18:?}"

## Assert existance of software
assert_file_executable "${JAVA6}"
assert_file_executable "${PYTHON}"
assert_file_executable "${BWA_OLD}"
assert_file_executable "${SAMTOOLS0_1_18}"
assert_file_exists "${PYTHON_REMOVEQC_GZ}"
assert_file_exists "${PICARD_FIXMATEINFO}"
assert_file_exists "${PICARD_ADD_OR_REPLACE_RG}"

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


TMP="${LG3_SCRATCH_ROOT}/${SAMPLE}/tmp"
make_dir "${TMP}"

echo "-------------------------------------------------"
echo "[Align] BWA alignment!"
echo "-------------------------------------------------"
echo "[Align] Fastq file #1: $fastq1"
echo "[Align] Fastq file #2: $fastq2"
echo "[Align] Prefix: $SAMPLE"
echo "[Align] BWA index: ${BWA_INDEX_OLD}"
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
  echo "[Align] Skipping chastity filtered (faked by a verbatim copy) ..."
  zcat "$fastq1" > "${SAMPLE}.read1.QC.fastq"
  assert_file_exists "${SAMPLE}.read1.QC.fastq"
  zcat "$fastq2" > "${SAMPLE}.read2.QC.fastq"
  assert_file_exists "${SAMPLE}.read2.QC.fastq"
fi

echo "[Align] Align first-in-pair reads..."
${BWA_OLD} aln -t "${ncores}" "${BWA_INDEX_OLD}" "${SAMPLE}.read1.QC.fastq" \
  > "${SAMPLE}.read1.sai" 2> "__${SAMPLE}_read1.log" || error "BWA alignment 1 failed"
assert_file_exists "${SAMPLE}.read1.sai"

echo "[Align] Align second-in-pair reads..."
${BWA_OLD} aln -t "${ncores}" "${BWA_INDEX_OLD}" "${SAMPLE}.read2.QC.fastq" \
  > "${SAMPLE}.read2.sai" 2> "__${SAMPLE}_read2.log" || error "BWA alignment 2 failed"
assert_file_exists "${SAMPLE}.read2.sai"

echo "[Align] Pair aligned reads..."
${BWA_OLD} sampe "${BWA_INDEX_OLD}" "${SAMPLE}.read1.sai" "${SAMPLE}.read2.sai" \
  "${SAMPLE}.read1.QC.fastq" "${SAMPLE}.read2.QC.fastq" > "${SAMPLE}.bwa.sam" 2>> "__${SAMPLE}.sampe.log" || error "BWA sampe failed"
assert_file_exists "${SAMPLE}.bwa.sam"

rm -f "${SAMPLE}.read1.QC.fastq"
rm -f "${SAMPLE}.read2.QC.fastq"

echo "[Align] Verify mate information..."
${JAVA6} -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_FIXMATEINFO}" \
        INPUT="${SAMPLE}.bwa.sam" \
        OUTPUT="${SAMPLE}.bwa.mateFixed.sam" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "Verify mate information failed"
assert_file_exists "${SAMPLE}.bwa.mateFixed.sam"

echo "[Align] Coordinate-sort and enforce read group assignments..."
${JAVA6} -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_ADD_OR_REPLACE_RG}" \
        INPUT="${SAMPLE}.bwa.mateFixed.sam" \
        OUTPUT="${SAMPLE}.bwa.sorted.sam" \
        SORT_ORDER=coordinate \
        RGID="$SAMPLE" \
        RGLB="$SAMPLE" \
        RGPL=$pl \
        RGPU=$pu \
        RGSM="$SAMPLE" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT || error "Sort failed"
assert_file_exists "${SAMPLE}.bwa.sorted.sam"

echo "[Align] Convert SAM to BAM..."
${SAMTOOLS0_1_18} view -bS "${SAMPLE}.bwa.sorted.sam" > "${SAMPLE}.trim.bwa.sorted.bam" || error "BAM conversion failed"
assert_file_exists "${SAMPLE}.trim.bwa.sorted.bam"

echo "[Align] Index the BAM file..."
${SAMTOOLS0_1_18} index "${SAMPLE}.trim.bwa.sorted.bam" || error "BAM indexing failed"
assert_file_exists "${SAMPLE}.trim.bwa.sorted.bam.bai"

echo "[Align] Clean up..."
rm -f "__${SAMPLE}"*.log
rm -f "${SAMPLE}"*.sai
rm -f "${SAMPLE}"*.sam
echo "[Align] Finished!"

echo "-------------------------------------------------"
echo "[QC] Calculate flag statistics..."
${SAMTOOLS0_1_18} flagstat "${SAMPLE}.trim.bwa.sorted.bam" > "${SAMPLE}.trim.bwa.sorted.flagstat" 2>&1
assert_file_exists "${SAMPLE}.trim.bwa.sorted.flagstat"
cat "${SAMPLE}.trim.bwa.sorted.flagstat"

echo "[QC] Finished!"
echo "-------------------------------------------------"
rm -rf "$TMP"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
