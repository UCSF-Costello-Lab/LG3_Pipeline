#!/bin/bash
#
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#
PROG=$(basename $0)
conversionfile=$1
patient=$2
mutfile=$3
outfile=$4

#conversionfile=/costellolab/mazort/LG3/exome/patient_ID_conversions.txt
echo "Warning ! Using trim-Conversion file $conversionfile !!!"

BIN=/home/jocostello/shared/LG3_Pipeline/scripts

python $BIN/libID_to_patientID.py ${mutfile} ${patient} ${outfile} ${conversionfile} || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

echo "Finished"
