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
unset PYTHONPATH  ## ADHOC: In case it is set by user

conversionfile=$1
patient=$2
mutfile=$3
outfile=$4
echo "Input:"
echo "- conversionfile=${conversionfile:?}"
echo "- patient=${patient:?}"
echo "- mutfile=${mutfile:?}"
echo "- outfile=${outfile:?}"
assert_file_exists "${mutfile}"
assert_file_exists "${conversionfile}"

echo "Warning ! Using Conversion file $conversionfile !!!"

python "${LG3_HOME}/scripts/libID_to_patientID.py" "${mutfile}" "${patient}" "${outfile}" "${conversionfile}" || error "Error on line $LINENO in $PROG"

echo "$PROG Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
