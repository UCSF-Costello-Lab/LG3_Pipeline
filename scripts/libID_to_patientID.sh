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
conversionfile=$1
patient=$2
mutfile=$3
outfile=$4

echo "Warning ! Using Conversion file $conversionfile !!!"

BIN=${LG3_HOME}/scripts

python "$BIN/libID_to_patientID.py" "${mutfile}" "${patient}" "${outfile}" "${conversionfile}" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

echo "$PROG Finished"
