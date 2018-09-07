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

conversionfile=$1
patient=$2
project=$3
PROG=$(basename "$0")

## run annotation code
python "${LG3_HOME}/scripts/annotate_mutations_from_bam.py" "${patient}.snvs" "${conversionfile}" "${patient}" "${project}" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

## remove intermediate files
rm -f "${patient}.snvs."*Q.txt

echo "Finished"
