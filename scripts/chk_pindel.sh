#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
PROJECT=${PROJECT:?}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "SCRATCHDIR=$SCRATCHDIR"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


RED='\033[0;31m'
GRN='\033[0;32m'
#YEL='\033[0;33m'
NOC='\033[0m'
OK="$GRN OK$NOC"
ERR="$RED missing$NOC"

if [ $# -eq 0 ]; then
        echo "ERROR: please specify patient!"
        exit 1
fi
project=LG3
echo -e "Checking Pindel output for project ${project}"

for patient in "$@"
do
        WORKDIR=${LG3_OUTPUT_ROOT}/${project:?}/pindel/${patient}_pindel
        ## Expected output:
        OUT=$WORKDIR/${patient}.indels.filtered.anno.txt
        if [ -s "$OUT" ]; then
                echo -e "${patient}" "$OK"
        else
                echo -e "${patient}" "$ERR"
        fi
done
