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


unset PYTHONPATH  ## ADHOC: In case it is set by user

## Input
MUTFILE=$1
PATIENT=$2
OUTFILE=$3
echo "Input:"
echo "- MUTFILE=${MUTFILE:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- OUTFILE=${OUTFILE:?}"

python "${LG3_HOME}/scripts/mutation_overlaps.py" "${MUTFILE}" "${PATIENT}" "${OUTFILE}" || error "mutation_overlaps.py failed"
assert_file_exists "${OUTFILE}"

awk -F'\t' '{print $NF}' "${OUTFILE}" | sort | uniq -c

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
