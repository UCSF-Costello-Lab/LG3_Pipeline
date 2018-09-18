#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-/costellolab/data1/jocostello}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_INPUT_ROOT=${LG3_INPUT_ROOT:?}"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- SCRATCHDIR=$SCRATCHDIR"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
fi


#
##
#
PROG=$(basename "$0")

### Input
patient=$1
project=$2
conversionfile=$3
echo "Input:"
echo " - patient=${patient:?}"
echo " - project=${project:?}"
echo " - conversionfile=${conversionfile:?}"
[[ -f "$conversionfile" ]] || { echo "File not found: ${conversionfile}"; exit 1; }

### Software
unset PYTHONPATH  ## ADHOC: In case it is set by user
RSCRIPT_BIN=/opt/R/R-latest/bin/Rscript
RSCRIPT_A=${LG3_HOME}/scripts/mutations_annotate_intersected_coverage.R
PYTHON_SCRIPT_A=${LG3_HOME}/scripts/convert_patient_wig2bed.py
[[ -x "$RSCRIPT_BIN" ]] || { echo "File not found or not an executable: ${RSCRIPT_BIN}"; exit 1; }
[[ -f "$RSCRIPT_A" ]] || { echo "File not found: ${RSCRIPT_A}"; exit 1; }
[[ -f "$PYTHON_SCRIPT_A" ]] || { echo "File not found: ${PYTHON_SCRIPT_A}"; exit 1; }


### FIXME: Are these input or output folders?
MUT=${LG3_OUTPUT_ROOT}/${project:?}/mutations/${patient}_mutect
MUT2=${LG3_OUTPUT_ROOT}/${project:?}/MutInDel
#[[ -d "$MUT" ]] || { echo "Folder not found: ${MUT}"; exit 1; }
#[[ -d "$MUT2" ]] || { echo "Folder not found: ${MUT2}"; exit 1; }

python "${PYTHON_SCRIPT_A}" "${patient}" "${project}" "${conversionfile}"  || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

"${RSCRIPT_BIN}" "${RSCRIPT_A}" "$MUT/${patient}.mutect.coverage.intersect.bed" "$MUT2/${patient}.snvs.indels.filtered.overlaps.txt" "$MUT2/${patient}.R.mutations"  || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
