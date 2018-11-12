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


#
##
#
PROG=$(basename "$0")
OK() {
        echo "OK: line ${BASH_LINENO[0]} in $PROG"
}

### Input
PATIENT=$1
PROJECT=$2
CONV=$3
echo "WARNING! Using conversion file $CONV !!!"
echo "Settings:"
echo " - PATIENT=${PATIENT:?}"
echo " - PROJECT=${PROJECT:?}"
echo " - CONV=${CONV:?}"
assert_file_exists "${CONV}"


### Software
unset PYTHONPATH  ## ADHOC: In case it is set by user
RSCRIPT_BIN=/opt/R/R-latest/bin/Rscript
PYTHON_RUNMAF=${LG3_HOME}/scripts/runMAF.py
R_MAFPLOT=${LG3_HOME}/scripts/MAFplot_version3_script.R
assert_file_executable "${RSCRIPT_BIN}"
assert_file_exists "${R_MAFPLOT}"
assert_file_exists "${PYTHON_RUNMAF}"


MAF=${LG3_OUTPUT_ROOT}/${PROJECT:?}/MAF
mkdir -p "${MAF}" || error "Can't create destination directory ${MAF}"

WDIR=${MAF}/${PATIENT}_MAF
mkdir -p "${WDIR}" || error "Can't create destination directory ${WDIR}"
cd "${WDIR}" || error "Failed to set working directory to ${WDIR}"

python "${PYTHON_RUNMAF}" "${PATIENT}" "${PROJECT}" "${CONV}" || error "${PYTHON_RUNMAF} failed"
OK

OUTDIR=${MAF}/${PATIENT}_plots
mkdir -p "${OUTDIR}" || error "Can't create destination directory ${OUTDIR}"
"${RSCRIPT_BIN}" "${R_MAFPLOT}" "${PATIENT}" "${PROJECT}" "${CONV}" || error "${R_MAFPLOT} failed"
OK

echo "Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
