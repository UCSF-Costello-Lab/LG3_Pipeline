#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:1}
CHASTITY_FILTERING=${CHASTITY_FILTERING:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- SCRATCHDIR=$SCRATCHDIR"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
  echo "- ncores=$ncores"
  echo "- CHASTITY_FILTERING=${CHASTITY_FILTERING:-?}"
fi

#
##
### Align Illumina PE exome sequence data from two fastq files with BWA.
###
### /path/to/Align_fastq.sh <fastq1> <fastq2> <output prefix>
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

## References
BWA_INDEX=${LG3_HOME}/resources/bwa_indices/hg19.bwa
echo "References:"
echo "- BWA_INDEX=${BWA_INDEX:?}"
BWA_INDEX_HOME=$(dirname "${BWA_INDEX}")
[[ -d "$BWA_INDEX_HOME" ]] || { echo "Folder not found: ${BWA_INDEX_HOME}"; exit 1; }

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
[[ -x "$JAVA" ]]     || { echo "Not an executable: ${JAVA}"; exit 1; }
[[ -x "$PYTHON" ]]   || { echo "Not an executable: ${PYTHON}"; exit 1; }
[[ -x "$BWA" ]]      || { echo "Not an executable: ${BWA}"; exit 1; }
[[ -x "$SAMTOOLS" ]] || { echo "Not an executable: ${SAMTOOLS}"; exit 1; }
[[ -f "$PYTHON_SCRIPT" ]] || { echo "File not found: ${PYTHON_SCRIPT}"; exit 1; }
[[ -f "$PICARD_SCRIPT_A" ]] || { echo "File not found: ${PICARD_SCRIPT_A}"; exit 1; }
[[ -f "$PICARD_SCRIPT_B" ]] || { echo "File not found: ${PICARD_SCRIPT_B}"; exit 1; }

### Input
pl="Illumina"
pu="Exome"
fastq1=$1
fastq2=$2
prefix=$3
echo "Input:"
echo "- fastq1=${fastq1:?}"
echo "- fastq2=${fastq2:?}"
echo "- prefix=${prefix:?}"
echo "- pl=${pl:?} (hard coded)"
echo "- pu=${pu:?} (hard coded)"

## Assert existance of input files
[[ -f "$fastq1" ]] || { echo "File not found: ${fastq1}"; exit 1; }
[[ -f "$fastq2" ]] || { echo "File not found: ${fastq2}"; exit 1; }


TMP="${SCRATCHDIR}/$prefix/tmp"
mkdir -p "${TMP}" || { echo "Can't create scratch directory ${TMP}"; exit 1; }

echo "-------------------------------------------------"
echo "[Align] BWA alignment!"
echo "-------------------------------------------------"
echo "[Align] Fastq file #1: $fastq1"
echo "[Align] Fastq file #2: $fastq2"
echo "[Align] Prefix: $prefix"
echo "[Align] BWA index: $BWA_INDEX"
echo "-------------------------------------------------"


if [[ "${CHASTITY_FILTERING}" == "true" ]]; then
  echo "[Align] Removing chastity filtered first-in-pair reads..."
  $PYTHON "${PYTHON_SCRIPT}" "$fastq1" \
          > "${prefix}.read1.QC.fastq" || { echo "Chastity filtering read1 failed"; exit 1; }

  echo "[Align] Removing chastity filtered second-in-pair reads..."
  $PYTHON "${PYTHON_SCRIPT}" "$fastq2" \
          > "${prefix}.read2.QC.fastq" || { echo "Chastity filtering read2 failed"; exit 1; }
else
  echo "[Align] Skipping chastity filtered (faked by a verbatim copy) ..."
  zcat "$fastq1" > "${prefix}.read1.QC.fastq"
  zcat "$fastq2" > "${prefix}.read2.QC.fastq"
fi

echo "[Align] Align first-in-pair reads..."
$BWA aln -t "${ncores}" "$BWA_INDEX" "${prefix}.read1.QC.fastq" \
  > "${prefix}.read1.sai" 2> "__${prefix}_read1.log" || { echo "BWA alignment failed"; exit 1; }

echo "[Align] Align second-in-pair reads..."
$BWA aln -t "${ncores}" "$BWA_INDEX" "${prefix}.read2.QC.fastq" \
  > "${prefix}.read2.sai" 2> "__${prefix}_read2.log" || { echo "BWA alignment failed"; exit 1; }

echo "[Align] Pair aligned reads..."
$BWA sampe "$BWA_INDEX" "${prefix}.read1.sai" "${prefix}.read2.sai" \
  "${prefix}.read1.QC.fastq" "${prefix}.read2.QC.fastq" > "${prefix}.bwa.sam" 2>> "__${prefix}.sampe.log" || { echo "BWA sampe failed"; exit 1; }

rm -f "${prefix}.read1.QC.fastq"
rm -f "${prefix}.read2.QC.fastq"

echo "[Align] Verify mate information..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_A}" \
        INPUT="${prefix}.bwa.sam" \
        OUTPUT="${prefix}.bwa.mateFixed.sam" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || { echo "Verify mate information failed"; exit 1; } 

echo "[Align] Coordinate-sort and enforce read group assignments..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_B}" \
        INPUT="${prefix}.bwa.mateFixed.sam" \
        OUTPUT="${prefix}.bwa.sorted.sam" \
        SORT_ORDER=coordinate \
        RGID="$prefix" \
        RGLB="$prefix" \
        RGPL=$pl \
        RGPU=$pu \
        RGSM="$prefix" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT || { echo "Sort failed"; exit 1; }

echo "[Align] Convert SAM to BAM..."
$SAMTOOLS view -bS "${prefix}.bwa.sorted.sam" > "${prefix}.trim.bwa.sorted.bam" || { echo "BAM conversion failed"; exit 1; }

echo "[Align] Index the BAM file..."
$SAMTOOLS index "${prefix}.trim.bwa.sorted.bam" || { echo "BAM indexing failed"; exit 1; }

echo "[Align] Clean up..."
rm -f "__${prefix}"*.log
rm -f "${prefix}"*.sai
rm -f "${prefix}"*.sam
echo "[Align] Finished!"

echo "-------------------------------------------------"
echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "${prefix}.trim.bwa.sorted.bam" > "${prefix}.trim.bwa.sorted.flagstat" 2>&1
echo "[QC] Finished!"
echo "-------------------------------------------------"
rm -rf "$TMP"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
