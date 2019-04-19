#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

# shellcheck source=scripts/config.sh
source "${LG3_HOME}/scripts/config.sh"

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

BEDTOOLS=/opt/BEDTools/BEDTools-2.16.2/bin/bedtools
PYTHON_PINDEL_FILTER=${LG3_HOME}/scripts/pindel_filter.py
assert_file_executable "${BEDTOOLS}"
assert_file_exists "${PYTHON_PINDEL_FILTER}"

datafile=$1
#proj=$2
interval=$3
echo "Input:"
echo "- datafile=${datafile:?}"
echo "- interval=${interval:?}"

assert_file_exists "${datafile}"

### filter indels
python "${PYTHON_PINDEL_FILTER}" "${datafile}"
assert_file_exists "${datafile}.filter"

### intersect with target sequence
"${BEDTOOLS}" intersect -a "${datafile}.filter" -b "${interval}" -wa > "${datafile}.filter.intersect"
assert_file_exists "${datafile}.filter.intersect"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
