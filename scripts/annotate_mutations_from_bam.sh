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


## Input
conversionfile=$1
patient=$2
project=$3
echo "Input:"
echo " - conversionfile=${conversionfile:?}"
echo " - patient=${patient:?}"
echo " - project=${project:?}"
[[ -f "$conversionfile" ]] || error "File not found: ${conversionfile}"

PROG=$(basename "$0")
unset PYTHONPATH  ## ADHOC: In case it is set by user

## run annotation code
python "${LG3_HOME}/scripts/annotate_mutations_from_bam.py" "${patient}.snvs" "${conversionfile}" "${patient}" "${project}" || error "Error on line $LINENO in $PROG"

## remove intermediate files
rm -f "${patient}.snvs."*Q.txt

echo "Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
