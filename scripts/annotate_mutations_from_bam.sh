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

## Input
CONV=$1
PATIENT=$2
PROJECT=$3
echo "Input:"
echo " - CONV=${CONV:?}"
echo " - PATIENT=${PATIENT:?}"
echo " - PROJECT=${PROJECT:?}"
assert_file_exists "${CONV}"

echo "Software:"
echo "- PYTHON=${PYTHON:?}"
assert_python "$PYTHON"
unset PYTHONPATH  ## ADHOC: In case it is set by user

## run annotation code
$PYTHON "${LG3_HOME}/scripts/annotate_mutations_from_bam.py" "${PATIENT}.snvs" "${CONV}" "${PATIENT}" "${PROJECT}" || error "annotate_mutations_from_bam.py failed"

## remove intermediate files
rm -f "${PATIENT}.snvs."*Q.txt

echo "Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
