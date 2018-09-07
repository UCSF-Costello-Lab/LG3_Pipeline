#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "SCRATCHDIR=$SCRATCHDIR"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


#
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#
PROG=$(basename "$0")
mutfile=$1
patient=$2
outfile=$3

BIN=${LG3_HOME}/scripts

python "$BIN/mutation_overlaps.py" "${mutfile}" "${patient}" "${outfile}" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

awk -F'\t' '{print $NF}' "${outfile}" | sort | uniq -c

echo "$PROG Finished"
