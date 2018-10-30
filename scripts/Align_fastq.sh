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
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}
LG3_CHASTITY_FILTERING=${LG3_CHASTITY_FILTERING:-true}

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
BWA_INDEX=${LG3_HOME}/resources/bwa_indices/hg19.bwa
echo "References:"
echo "- BWA_INDEX=${BWA_INDEX:?}"
BWA_INDEX_HOME=$(dirname "${BWA_INDEX}")
[[ -d "$BWA_INDEX_HOME" ]] || error "Folder not found: ${BWA_INDEX_HOME}"

## Software
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PYTHON=/usr/bin/python
BWA=${LG3_HOME}/tools/bwa-0.5.10/bwa
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
unset PYTHONPATH  ## ADHOC: In case it is set by user. /HB 2018-09-07

PYTHON_SCRIPT=${LG3_HOME}/scripts/removeQCgz.py
PICARD_SCRIPT_A=${LG3_HOME}/tools/picard-tools-1.64/FixMateInformation.jar
PICARD_SCRIPT_B=${LG3_HOME}/tools/picard-tools-1.64/AddOrReplaceReadGroups.jar

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- PYTHON=${PYTHON:?}"
echo "- BWA=${BWA:?}"
echo "- SAMTOOLS=${SAMTOOLS:?}"

## Assert existance of software
[[ -x "$JAVA" ]]     || error "Not an executable: ${JAVA}"
[[ -x "$PYTHON" ]]   || error "Not an executable: ${PYTHON}"
[[ -x "$BWA" ]]      || error "Not an executable: ${BWA}"
[[ -x "$SAMTOOLS" ]] || error "Not an executable: ${SAMTOOLS}"
[[ -f "$PYTHON_SCRIPT" ]] || error "File not found: ${PYTHON_SCRIPT}"
[[ -f "$PICARD_SCRIPT_A" ]] || error "File not found: ${PICARD_SCRIPT_A}"
[[ -f "$PICARD_SCRIPT_B" ]] || error "File not found: ${PICARD_SCRIPT_B}"

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
[[ -f "$fastq1" ]] || error "File not found: ${fastq1}"
[[ -f "$fastq2" ]] || error "File not found: ${fastq2}"


TMP="${LG3_SCRATCH_ROOT}/$SAMPLE/tmp"
mkdir -p "${TMP}" || error "Can't create scratch directory ${TMP}"

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
  $PYTHON "${PYTHON_SCRIPT}" "$fastq1" \
          > "${SAMPLE}.read1.QC.fastq" || error "Chastity filtering read1 failed"

  echo "[Align] Removing chastity filtered second-in-pair reads..."
  $PYTHON "${PYTHON_SCRIPT}" "$fastq2" \
          > "${SAMPLE}.read2.QC.fastq" || error "Chastity filtering read2 failed"
else
  echo "[Align] Skipping chastity filtered (faked by a verbatim copy) ..."
  zcat "$fastq1" > "${SAMPLE}.read1.QC.fastq"
  zcat "$fastq2" > "${SAMPLE}.read2.QC.fastq"
fi

echo "[Align] Align first-in-pair reads..."
$BWA aln -t "${ncores}" "$BWA_INDEX" "${SAMPLE}.read1.QC.fastq" \
  > "${SAMPLE}.read1.sai" 2> "__${SAMPLE}_read1.log" || error "BWA alignment failed"

echo "[Align] Align second-in-pair reads..."
$BWA aln -t "${ncores}" "$BWA_INDEX" "${SAMPLE}.read2.QC.fastq" \
  > "${SAMPLE}.read2.sai" 2> "__${SAMPLE}_read2.log" || error "BWA alignment failed"

echo "[Align] Pair aligned reads..."
$BWA sampe "$BWA_INDEX" "${SAMPLE}.read1.sai" "${SAMPLE}.read2.sai" \
  "${SAMPLE}.read1.QC.fastq" "${SAMPLE}.read2.QC.fastq" > "${SAMPLE}.bwa.sam" 2>> "__${SAMPLE}.sampe.log" || error "BWA sampe failed"

rm -f "${SAMPLE}.read1.QC.fastq"
rm -f "${SAMPLE}.read2.QC.fastq"

echo "[Align] Verify mate information..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_A}" \
        INPUT="${SAMPLE}.bwa.sam" \
        OUTPUT="${SAMPLE}.bwa.mateFixed.sam" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "Verify mate information failed"

echo "[Align] Coordinate-sort and enforce read group assignments..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_B}" \
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

echo "[Align] Convert SAM to BAM..."
$SAMTOOLS view -bS "${SAMPLE}.bwa.sorted.sam" > "${SAMPLE}.trim.bwa.sorted.bam" || error "BAM conversion failed"

echo "[Align] Index the BAM file..."
$SAMTOOLS index "${SAMPLE}.trim.bwa.sorted.bam" || error "BAM indexing failed"

echo "[Align] Clean up..."
rm -f "__${SAMPLE}"*.log
rm -f "${SAMPLE}"*.sai
rm -f "${SAMPLE}"*.sam
echo "[Align] Finished!"

echo "-------------------------------------------------"
echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "${SAMPLE}.trim.bwa.sorted.bam" > "${SAMPLE}.trim.bwa.sorted.flagstat" 2>&1
echo "[QC] Finished!"
echo "-------------------------------------------------"
rm -rf "$TMP"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
