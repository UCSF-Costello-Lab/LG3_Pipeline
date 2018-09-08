#!/bin/bash
#
##
### PINDEL
###
### /path/to/pindel_setup.sh
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

patient_ID=$1
proj=$2
patIDs=$3
python /home/jocostello/shared/LG3_Pipeline/scripts/pindel_wgs_setup.py "${patient_ID}" "${proj}" "${patIDs}"


