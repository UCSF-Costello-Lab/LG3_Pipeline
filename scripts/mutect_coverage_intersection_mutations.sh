#!/bin/bash
#
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#
PROG=$(basename $0)

patient=$1
project=$2
conversionfile=$3
BIN=/home/jocostello/shared/LG3_Pipeline/scripts
MUT=/costellolab/jocostello/${project}/mutations/${patient}_mutect
#MUT=/costellolab/jocostello/LG3/exomes2/exomes/Mutations2
MUT2=/costellolab/jocostello/${project}/MutInDel

python $BIN/convert_patient_wig2bed.py ${patient} ${project} ${conversionfile}  || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
/opt/R/R-latest/bin/Rscript $BIN/mutations_annotate_intersected_coverage.R $MUT/${patient}.mutect.coverage.intersect.bed $MUT2/${patient}.snvs.indels.filtered.overlaps.txt $MUT2/${patient}.R.mutations  || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

