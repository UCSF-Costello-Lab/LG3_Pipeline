#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

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
unset PYTHONPATH  ## ADHOC: In case it is set by user
RSCRIPT_BIN=/opt/R/R-latest/bin/Rscript
RSCRIPT_A=${LG3_HOME}/scripts/mutations_annotate_intersected_coverage.R
PYTHON_SCRIPT_A=${LG3_HOME}/scripts/convert_patient_wig2bed.py
assert_file_executable "${RSCRIPT_BIN}"
assert_file_exists "${RSCRIPT_A}"
assert_file_exists "${PYTHON_SCRIPT_A}"


### FIXME: Are these input or output folders?
MUT=${LG3_OUTPUT_ROOT}/${PROJECT:?}/mutations/${PATIENT}_mutect
#MUT2=${LG3_OUTPUT_ROOT}/${PROJECT:?}/MutInDel
MUT2=.

python "${PYTHON_SCRIPT_A}" "${PATIENT}" "${PROJECT}" "${CONV}"  || error "${PYTHON_SCRIPT_A} failed"

"${RSCRIPT_BIN}" "${RSCRIPT_A}" "$MUT/${PATIENT}.mutect.coverage.intersect.bed" "$MUT2/${PATIENT}.snvs.indels.filtered.overlaps.txt" "$MUT2/${PATIENT}.R.mutations"  || error "${RSCRIPT_A} failed"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
