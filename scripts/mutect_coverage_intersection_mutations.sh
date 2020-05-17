#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
PROJECT=${PROJECT:?}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_INPUT_ROOT=${LG3_INPUT_ROOT:?}"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
fi


### Input
PATIENT=$1
PROJECT=$2
CONV=$3
echo "Input:"
echo " - PATIENT=${PATIENT:?}"
echo " - PROJECT=${PROJECT:?}"
echo " - CONV=${CONV:?}"
assert_file_exists "${CONV}"

### Software
assert_python "$PYTHON"
unset PYTHONPATH  ## ADHOC: In case it is set by user
RSCRIPT_BIN=/opt/R/R-latest/bin/Rscript
R_MUT_ANN_INTERSECTED_COV=${LG3_HOME}/scripts/mutations_annotate_intersected_coverage.R
PYTHON_CONV_PAT_WIG2BED=${LG3_HOME}/scripts/convert_patient_wig2bed.py
assert_file_executable "${RSCRIPT_BIN}"
assert_file_exists "${R_MUT_ANN_INTERSECTED_COV}"
assert_file_exists "${PYTHON_CONV_PAT_WIG2BED}"


### FIXME: Are these input or output folders?
MUT=${LG3_OUTPUT_ROOT}/${PROJECT:?}/mutations/${PATIENT}_mutect
MUT2=.

$PYTHON "${PYTHON_CONV_PAT_WIG2BED}" "${PATIENT}" "${PROJECT}" "${CONV}"  || error "${PYTHON_CONV_PAT_WIG2BED} failed"
assert_file_exists  "$MUT/${PATIENT}.mutect.coverage.intersect.bed"

"${RSCRIPT_BIN}" "${R_MUT_ANN_INTERSECTED_COV}" "$MUT/${PATIENT}.mutect.coverage.intersect.bed" "$MUT2/${PATIENT}.snvs.indels.filtered.overlaps.txt" "$MUT2/${PATIENT}.R.mutations"  || error "${R_MUT_ANN_INTERSECTED_COV} failed"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
