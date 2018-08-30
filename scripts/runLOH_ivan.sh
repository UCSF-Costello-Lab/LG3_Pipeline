#!/bin/bash
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

MAF=/costellolab/data1/jocostello/${project}/MAF
BIN=/home/jocostello/shared/LG3_Pipeline/scripts

mkdir -p "$MAF/${patient}_MAF"
cd "$MAF/${patient}_MAF" || { echo "ERROR: Can't cd $MAF/${patient}_MAF"; exit 1; }
python $BIN/runMAF.py "${patient}" "${project}" "${conversionfile}" || { echo "ABORT: Error in $LINENO $PROG"; exit 1; }
OK $LINENO

mkdir -p "$MAF/${patient}_plots"
/opt/R/R-latest/bin/Rscript $BIN/MAFplot_version3_script.R "${patient}" "${project}" "${conversionfile}" || { echo "ABORT: Error in $LINENO $PROG"; exit 1; }
OK $LINENO

echo "Finished"
