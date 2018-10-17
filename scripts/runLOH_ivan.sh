#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
PROJECT=${PROJECT:?}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_INPUT_ROOT=${LG3_INPUT_ROOT:?}"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
fi


#
##
#
PROG=$(basename "$0")
OK() {
        echo "OK: line $1 in $PROG"
}

### Input
patient=$1
project=$2
conversionfile=$3
echo "WARNING! Using conversion file $conversionfile !!!"
echo "Settings:"
echo " - patient=${patient:?}"
echo " - project=${project:?}"
echo " - conversionfile=${conversionfile:?}"
[[ -f "$conversionfile" ]] || { echo "File not found: ${conversionfile}"; exit 1; }


### Software
unset PYTHONPATH  ## ADHOC: In case it is set by user
RSCRIPT_BIN=/opt/R/R-latest/bin/Rscript
PYTHON_SCRIPT_A=${LG3_HOME}/scripts/runMAF.py
RSCRIPT_A=${LG3_HOME}/scripts/MAFplot_version3_script.R
[[ -x "$RSCRIPT_BIN" ]] || { echo "File not found or not an executable: ${RSCRIPT_BIN}"; exit 1; }
[[ -f "$RSCRIPT_A" ]] || { echo "File not found: ${RSCRIPT_A}"; exit 1; }
[[ -f "$PYTHON_SCRIPT_A" ]] || { echo "File not found: ${PYTHON_SCRIPT_A}"; exit 1; }


MAF=${LG3_OUTPUT_ROOT}/${project:?}/MAF
mkdir -p "${MAF}" || { echo "Can't create destination directory ${MAF}"; exit 1; }

WDIR=${MAF}/${patient}_MAF
mkdir -p "${WDIR}" || { echo "Can't create destination directory ${WDIR}"; exit 1; }
cd "${WDIR}" || { echo "ERROR [$PROG:$LINENO]: Failed to set working directory to ${WDIR}"; exit 1; }

python "${PYTHON_SCRIPT_A}" "${patient}" "${project}" "${conversionfile}" || { echo "ABORT: Error in $LINENO $PROG"; exit 1; }
OK $LINENO

OUTDIR=${MAF}/${patient}_plots
mkdir -p "${OUTDIR}" || { echo "Can't create destination directory ${OUTDIR}"; exit 1; }
"${RSCRIPT_BIN}" "${RSCRIPT_A}" "${patient}" "${project}" "${conversionfile}" || { echo "ABORT: Error in $LINENO $PROG"; exit 1; }
OK $LINENO

echo "Finished"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
