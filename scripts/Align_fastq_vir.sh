#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}

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
fi


#
##
### Align Illumina PE exome sequence data from two fastq files with BWA.
###
### /path/to/Align_fastq.sh <fastq1> <fastq2> <output prefix>
##
#

BWA=${LG3_HOME}/tools/bwa-0.5.10/bwa
BWA_INDEX="${LG3_HOME}/resources/E6E7/E6E7.fa"
#BWA_INDEX="${LG3_HOME}/resources/bwa_indices/hg19.bwa"
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
PYTHON=/usr/bin/python
pl="Illumina"
pu="Exome"

fastq1=$1
fastq2=$2
prefix=$3
TMP="${SCRATCHDIR}/$prefix/tmp"
mkdir -p "$TMP"

echo "-------------------------------------------------"
echo "[Align] BWA alignment!"
echo "-------------------------------------------------"
echo "[Align] Fastq file #1: $fastq1"
echo "[Align] Fastq file #2: $fastq2"
echo "[Align] Prefix: $prefix"
echo "[Align] BWA index: $BWA_INDEX"
echo "-------------------------------------------------"

echo "[Align] Removing chastity filtered first-in-pair reads..."
$PYTHON "${LG3_HOME}/scripts/removeQC.py" "$fastq1" \
        > "${prefix}.read1.QC.fastq"|| { echo "Chastity filtering read1 failed"; exit 1; }

echo "[Align] Removing chastity filtered second-in-pair reads..."
$PYTHON "${LG3_HOME}/scripts/removeQC.py" "$fastq2" \
        > "${prefix}.read2.QC.fastq" || { echo "Chastity filtering read2 failed"; exit 1; }

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
        -jar "${LG3_HOME}/tools/picard-tools-1.64/FixMateInformation.jar" \
        INPUT="${prefix}.bwa.sam" \
        OUTPUT="${prefix}.bwa.mateFixed.sam" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || { echo "Verify mate information failed"; exit 1; } 

echo "[Align] Coordinate-sort and enforce read group assignments..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/AddOrReplaceReadGroups.jar" \
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
$SAMTOOLS view -bS "${prefix}.bwa.sorted.sam" > "${prefix}.bwa.sorted.bam" || { echo "BAM conversion failed"; exit 1; }

echo "[Align] Index the BAM file..."
$SAMTOOLS index "${prefix}.bwa.sorted.bam" || { echo "BAM indexing failed"; exit 1; }

echo "[Align] Clean up..."
rm -f "__${prefix}*.log"
rm -f "${prefix}*.sai"
rm -f "${prefix}*.sam"
echo "[Align] Finished!"

echo "-------------------------------------------------"
echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "${prefix}.bwa.sorted.bam" > "${prefix}.bwa.sorted.flagstat" 2>&1
echo "[QC] Finished!"
echo "-------------------------------------------------"
rm -rf "$TMP"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
