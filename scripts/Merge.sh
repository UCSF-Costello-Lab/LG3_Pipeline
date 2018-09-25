#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
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
TMP=${LG3_SCRATCH_ROOT}
pl="Illumina"
pu="Exome"
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PICARD=${LG3_HOME}/tools/picard-tools-1.64
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools

#Input variables
bamfiles=$1
prefix=$2

echo "------------------------------------------------------"
echo "[Merge] Merge technical replicates"
echo "------------------------------------------------------"
echo "[Merge] Merge Group: $prefix"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Merge] Exome:"$i}'
echo "------------------------------------------------------"

## Construct string with one or more '-I <bam>' elements
inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo "[Merge] Merge BAM files..."
# shellcheck disable=SC2086
# Comment: Because how 'inputs' is created and used below
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
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

echo "[Merge] make symbolic link for downstream compatibility..."
ln -sf "${prefix}.merged.sorted.bam" "${prefix}.bwa.realigned.rmDups.recal.bam"
ln -sf "${prefix}.merged.sorted.bam.bai" "${prefix}.bwa.realigned.rmDups.recal.bam.bai"

echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "${prefix}.merged.sorted.bam" > "${prefix}.merged.sorted.flagstat" 2>&1

echo "[Merge] Finished!"
echo "------------------------------------------------------"
