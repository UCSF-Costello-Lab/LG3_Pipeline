#!/bin/bash
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
python /home/jocostello/shared/LG3_Pipeline/scripts/pindel_filter.py "${datafile}"

### intersect with target sequence
/opt/BEDTools/BEDTools-2.16.2/bin/bedtools intersect -a "${datafile}.filter" -b "${interval}" -wa > "${datafile}.filter.intersect"

