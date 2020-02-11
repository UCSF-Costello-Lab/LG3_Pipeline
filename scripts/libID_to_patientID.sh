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

PROG=$(basename "$0")
unset PYTHONPATH  ## ADHOC: In case it is set by user

CONV=$1
PATIENT=$2
MUTFILE=$3
OUTFILE=$4
echo "Input:"
echo "- CONV=${CONV:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- MUTFILE=${MUTFILE:?}"
echo "- OUTFILE=${OUTFILE:?}"
assert_file_exists "${MUTFILE}"
assert_file_exists "${CONV}"

python "${LG3_HOME}/scripts/libID_to_patientID.py" "${MUTFILE}" "${PATIENT}" "${OUTFILE}" "${CONV}" || error "libID_to_patientID.py failed"
assert_file_exists "${OUTFILE}"

echo "$PROG Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
