#!/bin/bash
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

BIN=/home/jocostello/shared/LG3_Pipeline/scripts

python $BIN/mutation_overlaps.py "${mutfile}" "${patient}" "${outfile}" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

awk -F'\t' '{print $NF}' "${outfile}" | sort | uniq -c

echo "$PROG Finished"
