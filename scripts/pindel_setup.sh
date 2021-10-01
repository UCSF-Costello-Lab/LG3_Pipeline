#!/bin/bash

# shellcheck disable=SC1091
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${TMPDIR:-/scratch/${SLURM_JOB_USER}/${SLURM_JOB_ID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if $LG3_DEBUG ; then
  echo "Debug info:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_INPUT_ROOT=$LG3_INPUT_ROOT"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- hostname=$(hostname)"
  echo "- node(s): ${SLURM_JOB_NODELIST}"
  echo "- SLURM_NTASKS: ${SLURM_NTASKS}"
fi

### PINDEL
###
### /path/to/pindel_setup.sh

assert_python "$PYTHON"

PYTHON_PINDEL_SETUP=${LG3_HOME}/scripts/pindel_setup.py
assert_file_exists "${PYTHON_PINDEL_SETUP}"

patient_ID=$1
proj=$2
patIDs=$3
echo "Input:"
echo "- patient_ID=${patient_ID:?}"
echo "- proj=${proj:?}"
echo "- patIDs=${patIDs:?}"

assert_patient_name "${patient_ID}"
assert_file_exists "${patIDs}"

$PYTHON "${PYTHON_PINDEL_SETUP}" "${patient_ID}" "${proj}" "${patIDs}"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
