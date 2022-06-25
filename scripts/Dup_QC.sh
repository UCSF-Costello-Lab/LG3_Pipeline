#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

module load samtools/1.15

PROGRAM=${BASH_SOURCE[0]}
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
mem=${SLURM_MEM:-1}
time=${SLURM_TIME:-1}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- hostname=$(hostname)"
  echo "- ncores=$ncores"
  echo "- mem=$mem"
  echo "- time=$time"
fi

## Software
echo "- JAVA=${JAVA:?}"
which samtools
echo "- GATK=${GATK:?}"
echo "- PICARD_HOME=${PICARD_HOME:?}"

PICARD_FIXMATEINFO=${PICARD_HOME}/FixMateInformation.jar
PICARD_MARKDUPS=${PICARD_HOME}/MarkDuplicates.jar
assert_file_exists "${PICARD_FIXMATEINFO}"
assert_file_exists "${PICARD_MARKDUPS}"

BAM=$1
SAMPLE=$2
OUT="${SAMPLE}.Dups.bam"
echo "Input:"
echo "- BAM=${BAM:?}"
echo "- SAMPLE=${SAMPLE:?}"
## Assert existance of input files
assert_file_exists "${BAM}"


TMP="${LG3_SCRATCH_ROOT}/$SAMPLE/tmp"
make_dir "${TMP}"

echo "-------------------------------------------------"
echo "[QC] Mark Duplicates"
echo "-------------------------------------------------"

{ time $JAVA -Xmx32g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_MARKDUPS}" \
        INPUT="${BAM}" \
        OUTPUT="${OUT}" \
        METRICS_FILE="${SAMPLE}.markdups.metrics" \
        REMOVE_DUPLICATES=FALSE \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT; } 2>&1 || error "Mark duplicates failed"

assert_file_exists "${OUT}"
assert_file_exists "${SAMPLE}.markdups.metrics"

echo "-------------------------------------------------"
echo "[QC] Calculate flag statistics..."
echo "-------------------------------------------------"
samtools flagstat "${OUT}" > "${SAMPLE}.trim.bwa.sorted.flagstat2" 2>&1
assert_file_exists "${SAMPLE}.trim.bwa.sorted.flagstat2"
cat "${SAMPLE}.trim.bwa.sorted.flagstat2"

echo "[QC] Finished!"
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
