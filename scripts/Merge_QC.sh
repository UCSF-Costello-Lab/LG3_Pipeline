#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

PROGRAM=${BASH_SOURCE[0]}
PROG=$(basename "$PROGRAM")
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:?}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${SLURM_NTASKS:-1}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "${PROG} Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- hostname=$(hostname)"
  echo "- ncores=$ncores"
fi


#
## Merge BAM files and enforce read group assignments
#
## Usage: /path/to/Merge.sh <bamfiles> <prefix> 
#
#
export PATH=/opt/R/R-latest/bin:$PATH

#Define resources and tools
pl="Illumina"
pu="Exome"
REF=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa

#Input variables
bamfiles=$1
prefix=$2
ILIST=$3

TMP="${LG3_SCRATCH_ROOT}/${prefix}_tmp"
make_dir "$TMP"

echo "------------------------------------------------------"
echo "[Merge] Merge technical replicates"
echo "------------------------------------------------------"
echo "[Merge] Merge Group: $prefix"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Merge] Exome:"$i}'
echo "[Merge] Intervals: $ILIST"
echo "------------------------------------------------------"

## Construct string with one or more '-I "<bam>"' elements
inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo "[Merge] Merge BAM files..."
# shellcheck disable=SC2086
# Comment: Because how 'inputs' is created and used below
$JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
        -jar "$PICARD_HOME/MergeSamFiles.jar" \
        ${inputs} \
        OUTPUT="${prefix}.merged.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "Merge BAM files failed"
assert_file_exists "${prefix}.merged.bam"

echo "[Merge] Index new BAM file..."
$SAMTOOLS index "${prefix}.merged.bam" || error "First indexing failed"
assert_file_exists "${prefix}.merged.bam.bai"


echo "[Merge] Coordinate-sort and enforce read group assignments..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
        -jar "$PICARD_HOME/AddOrReplaceReadGroups.jar" \
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
        VALIDATION_STRINGENCY=LENIENT || error "Sort failed"
assert_file_exists "${prefix}.merged.sorted.sam"

rm -f "${prefix}.merged.bam"
rm -f "${prefix}.merged.bam.bai"

echo "[Merge] Convert SAM to BAM..."
$SAMTOOLS view -bS "${prefix}.merged.sorted.sam" > "${prefix}.merged.sorted.bam" || error "BAM conversion failed"
assert_file_exists "${prefix}.merged.sorted.bam"

rm -f "${prefix}.merged.sorted.sam"

echo "[Merge] Index the BAM file..."
$SAMTOOLS index "${prefix}.merged.sorted.bam" || error "BAM indexing failed"

echo "[Merge] make symbolic link for downstream compatibility..."
ln -sf "${prefix}.merged.sorted.bam" "${prefix}.bwa.realigned.rmDups.recal.bam"
ln -sf "${prefix}.merged.sorted.bam.bai" "${prefix}.bwa.realigned.rmDups.recal.bam.bai"

echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "${prefix}.merged.sorted.bam" > "${prefix}.merged.sorted.flagstat" 2>&1
assert_file_exists "${prefix}.merged.sorted.flagstat"

echo "[QC] Calculate hybrid selection metrics..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/CalculateHsMetrics.jar" \
        BAIT_INTERVALS="${ILIST}" \
        TARGET_INTERVALS="${ILIST}" \
        INPUT="${prefix}.merged.sorted.bam" \
        OUTPUT="${prefix}.merged.hybrid_selection_metrics" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "Calculate hybrid selection metrics failed"
assert_file_exists "${prefix}.merged.hybrid_selection_metrics"

echo "[QC] Collect multiple QC metrics..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/CollectMultipleMetrics.jar" \
        INPUT="${prefix}.merged.sorted.bam" \
        OUTPUT="${prefix}.merged" \
        REFERENCE_SEQUENCE="${REF}" \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "Collect multiple QC metrics failed"
        for EXT in alignment_summary_metrics insert_size_metrics quality_by_cycle_metrics quality_distribution_metrics
        do
            assert_file_exists  "${prefix}.merged.${EXT}"
        done

echo "[QC] Finished!"

echo "[Merge] Success!"
echo "------------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
