#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"


### Configuration
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
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

if [ $# -eq 0 ]; then
    error "Please specify at least one patient!"
fi

echo -e "Checking Pindel output for project ${PROJECT:?}"

for PATIENT in "$@"
do
        WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/pindel/${PATIENT}_pindel
        ## Expected output:
        OUT=$WORKDIR/${PATIENT}.indels.filtered.anno.txt
        if [ -s "$OUT" ]; then
                echo -e "${PATIENT}" "$OK"
        else
                echo -e "${PATIENT}" "$ERR"
		error "${PATIENT} failed"
        fi
done

