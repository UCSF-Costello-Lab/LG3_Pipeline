#!/bin/bash
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

python /home/jocostello/shared/LG3_Pipeline/scripts/combine_snvs.py "${patient}" "${project}" "${conversionfile}" "${patient}.snvs" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

echo "Finished"
