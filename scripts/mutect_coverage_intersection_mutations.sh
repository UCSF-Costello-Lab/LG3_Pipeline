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

patient=$1
project=$2
conversionfile=$3
BIN=${LG3_HOME}/scripts
MUT=${LG3_OUTPUT_ROOT}/${project:?}/mutations/${patient}_mutect
MUT2=${LG3_OUTPUT_ROOT}/${project:?}/MutInDel

python "$BIN/convert_patient_wig2bed.py" "${patient}" "${project}" "${conversionfile}"  || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
/opt/R/R-latest/bin/Rscript "$BIN/mutations_annotate_intersected_coverage.R" "$MUT/${patient}.mutect.coverage.intersect.bed" "$MUT2/${patient}.snvs.indels.filtered.overlaps.txt" "$MUT2/${patient}.R.mutations"  || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

