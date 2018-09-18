#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_INPUT_ROOT=${LG3_INPUT_ROOT:?}"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- SCRATCHDIR=$SCRATCHDIR"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
fi


#
##
#
PROG=$(basename "$0")
unset PYTHONPATH  ## ADHOC: In case it is set by user

### Input
patient=$1
project=$2
conversionfile=$3
echo "Settings:"
echo " - patient=${patient:?}"
echo " - project=${project:?}"
echo " - conversionfile=${conversionfile:?}"
[[ -f "$conversionfile" ]] || { echo "File not found: ${conversionfile}"; exit 1; }

python "${LG3_HOME}/scripts/combine_snvs.py" "${patient}" "${project}" "${conversionfile}" "${patient}.snvs" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

echo "Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
