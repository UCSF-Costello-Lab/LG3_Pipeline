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
OK() {
        echo "OK: line $1 in $PROG"
}
patient=$1
project=$2
conversionfile=$3
echo "WARNING! Using conversion file $conversionfile !!!"

MAF=${LG3_OUTPUT_ROOT}/${project:?}/MAF
BIN=${LG3_HOME}/scripts

mkdir -p "$MAF/${patient}_MAF"
cd "$MAF/${patient}_MAF" || { echo "ERROR: Can't cd $MAF/${patient}_MAF"; exit 1; }
python "$BIN/runMAF.py" "${patient}" "${project}" "${conversionfile}" || { echo "ABORT: Error in $LINENO $PROG"; exit 1; }
OK $LINENO

mkdir -p "$MAF/${patient}_plots"
/opt/R/R-latest/bin/Rscript "$BIN/MAFplot_version3_script.R" "${patient}" "${project}" "${conversionfile}" || { echo "ABORT: Error in $LINENO $PROG"; exit 1; }
OK $LINENO

echo "Finished"
