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
### /path/to/pindel_filter.sh <pindel_output_all>
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

BEDTOOLS=/opt/BEDTools/BEDTools-2.16.2/bin/bedtools
PYTHON_SCRIPT_A=${LG3_HOME}/scripts/pindel_filter.py
[[ -x "$BEDTOOLS" ]] || { echo "File not found: ${BEDTOOLS}"; exit 1; }
[[ -f "$PYTHON_SCRIPT_A" ]] || { echo "File not found: ${PYTHON_SCRIPT_A}"; exit 1; }

datafile=$1
#proj=$2
interval=$3
echo "Input:"
echo "- datafile=${datafile:?}"
echo "- interval=${interval:?}"

[[ -f "$datafile" ]] || { echo "File not found: ${datafile}"; exit 1; }

### filter indels
python "${PYTHON_SCRIPT_A}" "${datafile}"

### intersect with target sequence
"${BEDTOOLS}" intersect -a "${datafile}.filter" -b "${interval}" -wa > "${datafile}.filter.intersect"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
