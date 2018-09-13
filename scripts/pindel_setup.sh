#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- SCRATCHDIR=$SCRATCHDIR"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
fi

#
##
### PINDEL
###
### /path/to/pindel_setup.sh
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

PYTHON_SCRIPT_A=${LG3_HOME}/scripts/pindel_setup.py
[[ -f "$PYTHON_SCRIPT_A" ]] || { echo "File not found: ${PYTHON_SCRIPT_A}"; exit 1; }

patient_ID=$1
proj=$2
patIDs=$3
echo "Input:"
echo "- patient_ID=${patient_ID:?}"
echo "- proj=${proj:?}"
echo "- patIDs=${patIDs:?}"

python "${PYTHON_SCRIPT_A}" "${patient_ID}" "${proj}" "${patIDs}"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
