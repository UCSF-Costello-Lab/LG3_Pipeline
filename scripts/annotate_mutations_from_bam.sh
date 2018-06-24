#!/bin/bash
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
PROG=$(basename $0)

## run annotation code
python /home/jocostello/shared/LG3_Pipeline/scripts/annotate_mutations_from_bam.py ${patient}.snvs ${conversionfile} ${patient} ${project} || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

## remove intermediate files
rm -f ${patient}.snvs.*Q.txt

echo "Finished"
