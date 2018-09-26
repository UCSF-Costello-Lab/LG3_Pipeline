#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


RED='\033[0;31m'
GRN='\033[0;32m'
#YEL='\033[0;33m'
NOC='\033[0m'
OK="$GRN OK$NOC"
ERR="$RED missing$NOC"

if [ $# -lt 2 ]; then
        echo "ERROR: please specify project and at least one patient!"
        exit 1
fi

PROJECT=$1
shift
echo -e "Checking Pindel output for project ${PROJECT}"

for patient in "$@"
do
        WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT:?}/pindel/${patient}_pindel
        ## Expected output:
        OUT=$WORKDIR/${patient}.indels.filtered.anno.txt
        if [ -s "$OUT" ]; then
                echo -e "${patient}" "$OK"
        else
                echo -e "${patient}" "$ERR"
        fi
done
