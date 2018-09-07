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
### PINDEL
###
### /path/to/pindel_filter.sh <pindel_output_all>
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

datafile=$1
#proj=$2
interval=$3

### filter indels
python "${LG3_HOME}/scripts/pindel_filter.py" "${datafile}"

### intersect with target sequence
/opt/BEDTools/BEDTools-2.16.2/bin/bedtools intersect -a "${datafile}.filter" -b "${interval}" -wa > "${datafile}.filter.intersect"

