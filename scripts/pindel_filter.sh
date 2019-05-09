#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
fi

#
##
### PINDEL
###
### /path/to/pindel_filter.sh <pindel_output_all>
##
#

PYTHON_PINDEL_FILTER=${LG3_HOME}/scripts/pindel_filter.py
assert_file_executable "${BEDTOOLS:?}"
assert_file_exists "${PYTHON_PINDEL_FILTER}"

datafile=$1
#PROJECT=$2
#TARGET=$3
echo "Input:"
echo "- datafile=${datafile:?}"
echo "- TARGET=${TARGET:?}"

assert_file_exists "${datafile}"

### filter indels
python "${PYTHON_PINDEL_FILTER}" "${datafile}"
assert_file_exists "${datafile}.filter"

### intersect with target sequence
"${BEDTOOLS}" intersect -a "${datafile}.filter" -b "${TARGET}" -wa > "${datafile}.filter.intersect"
assert_file_exists "${datafile}.filter.intersect"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
