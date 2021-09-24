#!/bin/bash

# shellcheck disable=SC1072,SC1073
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
if $LG3_DEBUG ; then
  echo "Debug info:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_INPUT_ROOT=${LG3_INPUT_ROOT:?}"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- node(s): ${SLURM_JOB_NODELIST}"
  echo "- SLURM_NTASKS: ${SLURM_NTASKS}"
  ${RSCRIPT} --version || error "No Rscript"
fi


PROG=$(basename "$0")
OK() {
        echo "OK: line ${BASH_LINENO[0]} in $PROG"
}

### Input
PATIENT=$1
PROJECT=$2
CONV=$3
echo "Settings:"
echo " - PATIENT=${PATIENT:?}"
echo " - PROJECT=${PROJECT:?}"
echo " - CONV=${CONV:?}"
assert_file_exists "${CONV}"


### Software
assert_python "$PYTHON"
unset PYTHONPATH  ## ADHOC: In case it is set by user
PYTHON_RUNMAF=${LG3_HOME}/scripts/runMAF.py
R_MAFPLOT=${LG3_HOME}/scripts/MAFplot_version3_script.R
assert_file_exists "${R_MAFPLOT}"
assert_file_exists "${PYTHON_RUNMAF}"


MAF=${LG3_OUTPUT_ROOT}/${PROJECT:?}/MAF
make_dir "${MAF}"

WDIR=${MAF}/${PATIENT}_MAF
make_dir "${WDIR}"
change_dir "${WDIR}"

$PYTHON "${PYTHON_RUNMAF}" "${PATIENT}" "${PROJECT}" "${CONV}" || error "${PYTHON_RUNMAF} failed"
OK

OUTDIR=${MAF}/${PATIENT}_plots
make_dir "${OUTDIR}"
"${RSCRIPT}" "${R_MAFPLOT}" "${PATIENT}" "${PROJECT}" "${CONV}" || error "${R_MAFPLOT} failed"
OK

echo "Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
