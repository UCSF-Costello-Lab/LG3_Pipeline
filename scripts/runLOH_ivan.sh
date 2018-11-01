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
        echo "OK: line $1 in $PROG"
}

### Input
patient=$1
project=$2
conversionfile=$3
echo "WARNING! Using conversion file $conversionfile !!!"
echo "Settings:"
echo " - patient=${patient:?}"
echo " - project=${project:?}"
echo " - conversionfile=${conversionfile:?}"
assert_file_exists "${conversionfile}"


### Software
unset PYTHONPATH  ## ADHOC: In case it is set by user
RSCRIPT_BIN=/opt/R/R-latest/bin/Rscript
PYTHON_SCRIPT_A=${LG3_HOME}/scripts/runMAF.py
RSCRIPT_A=${LG3_HOME}/scripts/MAFplot_version3_script.R
assert_file_executable "${RSCRIPT_BIN}"
assert_file_exists "${RSCRIPT_A}"
assert_file_exists "${PYTHON_SCRIPT_A}"


MAF=${LG3_OUTPUT_ROOT}/${project:?}/MAF
mkdir -p "${MAF}" || error "Can't create destination directory ${MAF}"

WDIR=${MAF}/${patient}_MAF
mkdir -p "${WDIR}" || error "Can't create destination directory ${WDIR}"
cd "${WDIR}" || error "Failed to set working directory to ${WDIR}"

python "${PYTHON_SCRIPT_A}" "${patient}" "${project}" "${conversionfile}" || error "${PYTHON_SCRIPT_A} failed"
OK $LINENO

OUTDIR=${MAF}/${patient}_plots
mkdir -p "${OUTDIR}" || error "Can't create destination directory ${OUTDIR}"
"${RSCRIPT_BIN}" "${RSCRIPT_A}" "${patient}" "${project}" "${conversionfile}" || error "${RSCRIPT_A} failed"
OK $LINENO

echo "Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
