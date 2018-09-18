#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "SCRATCHDIR=$SCRATCHDIR"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


#
## Merge BAM files and enforce read group assignments
#
## Usage: /path/to/Merge.sh <bamfiles> <prefix> 
#
#
# shellcheck source=.bashrc
source "${LG3_HOME}/.bashrc"
PATH=/opt/R/R-latest/bin/R:$PATH

#Define resources and tools
pl="Illumina"
pu="Exome"
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PICARD=${LG3_HOME}/tools/picard-tools-1.64
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
REF=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa

#Input variables
bamfiles=$1
prefix=$2
ilist=$3

TMP="${SCRATCHDIR}/${prefix}_tmp"
mkdir -p "$TMP"

echo "------------------------------------------------------"
echo "[Merge] Merge technical replicates"
echo "------------------------------------------------------"
echo "[Merge] Merge Group: $prefix"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Merge] Exome:"$i}'
echo "[Merge] Intervals: $ilist"
echo "------------------------------------------------------"

## Construct string with one or more '-I <bam>' elements
inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo "[Merge] Merge BAM files..."
# shellcheck disable=SC2086
# Comment: Because how 'inputs' is created and used below
$JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
        -jar "$PICARD/MergeSamFiles.jar" \
        ${inputs} \
        OUTPUT="${prefix}.merged.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || { echo "Merge BAM files failed"; exit 1; }

echo "[Merge] Index new BAM file..."
$SAMTOOLS index "${prefix}.merged.bam" || { echo "First indexing failed"; exit 1; }


echo "[Merge] Coordinate-sort and enforce read group assignments..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "$PICARD/AddOrReplaceReadGroups.jar" \
        INPUT="${prefix}.merged.bam" \
        OUTPUT="${prefix}.merged.sorted.sam" \
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

rm -f "${prefix}.merged.bam"
rm -f "${prefix}.merged.bam.bai"

echo "[Merge] Convert SAM to BAM..."
$SAMTOOLS view -bS "${prefix}.merged.sorted.sam" > "${prefix}.merged.sorted.bam" || { echo "BAM conversion failed"; exit 1; }

rm -f "${prefix}.merged.sorted.sam"

echo "[Merge] Index the BAM file..."
$SAMTOOLS index "${prefix}.merged.sorted.bam" || { echo "BAM indexing failed"; exit 1; }

echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "${prefix}.merged.sorted.bam" > "${prefix}.merged.sorted.flagstat" 2>&1

echo "[QC] Calculate hybrid selection metrics..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/CalculateHsMetrics.jar" \
        BAIT_INTERVALS="${ilist}" \
        TARGET_INTERVALS="${ilist}" \
        INPUT="${prefix}.merged.sorted.bam" \
        OUTPUT="${prefix}.merged.hybrid_selection_metrics" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

echo "[QC] Collect multiple QC metrics..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/CollectMultipleMetrics.jar" \
        INPUT="${prefix}.merged.sorted.bam" \
        OUTPUT="${prefix}.merged" \
        REFERENCE_SEQUENCE="${REF}" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }

echo "[QC] Finished!"

echo "[Merge] Success!"
echo "------------------------------------------------------"
