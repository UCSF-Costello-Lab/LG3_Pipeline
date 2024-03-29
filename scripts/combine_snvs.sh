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
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
fi


echo "Software:"
echo "- PYTHON=${PYTHON:?}"
echo "- RSCRIPT=${RSCRIPT:?}"
assert_python "$PYTHON"
unset PYTHONPATH  ## ADHOC: In case it is set by user
assert_file_exists "${LG3_HOME}/scripts/combine_snvs.py"

### Input
PATIENT=$1
PROJECT=$2
CONV=$3
echo "Settings:"
echo " - PATIENT=${PATIENT:?}"
echo " - PROJECT=${PROJECT:?}"
echo " - CONV=${CONV:?}"
assert_file_exists "${CONV}"

$PYTHON "${LG3_HOME}/scripts/combine_snvs.py" "${PATIENT}" "${PROJECT}" "${CONV}" "${PATIENT}.snvs" || error "combine_snvs.py failed"
assert_file_exists "${PATIENT}.snvs"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
