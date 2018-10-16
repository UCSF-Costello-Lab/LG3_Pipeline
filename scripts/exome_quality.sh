#!/bin/bash
PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

echo "----- Arguments received:"
echo "LG3_HOME = ${LG3_HOME}"
echo "LG3_OUTPUT_ROOT = ${LG3_OUTPUT_ROOT}"
echo "PROJECT = ${PROJECT}"
echo "PATIENT = ${PATIENT}"
echo "CONV = ${CONV}"
echo "BAMPATH = ${BAMPATH}"
echo "REF = ${REF}"
echo "MUTATIONFILE = ${MUTATIONFILE}"
echo -e "\n-----------\n\n"

module load CBC r/3.4.4
Rscript --version
module load CBC python/2.7.9
python --version

SCRIPT_A=${LG3_HOME}/scripts/plot_qualinfo.py
[[ -f "${SCRIPT_A}" ]] || { echo "ERROR: File not found: ${SCRIPT_A}"; exit 1; }

SCRIPT_B=${LG3_HOME}/scripts/plot_qualinfo.R
[[ -f "${SCRIPT_B}" ]] || { echo "ERROR: File not found: ${SCRIPT_B}"; exit 1; }

SCRIPT_C=${LG3_HOME}/scripts/coveragePlots.R
[[ -f "${SCRIPT_C}" ]] || { echo "ERROR: File not found: ${SCRIPT_C}"; exit 1; }

SCRIPT_D=${LG3_HOME}/scripts/afTERThought.py
[[ -f "${SCRIPT_D}" ]] || { echo "ERROR: File not found: ${SCRIPT_D}"; exit 1; }

WDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/QC_plots/${PATIENT}
mkdir -p "${WDIR}"
cd "${WDIR}" || { echo "ERROR: cd into ${WDIR} failed!"; exit 1; }

## reformat quality info file
echo -e "\\n=== reformat quality info file"
python "${SCRIPT_A}" "${REF}" "${MUTATIONFILE}" "${PATIENT}.qualityinfo.tmp" || { echo "ERROR: ${SCRIPT_A} FAILED"; exit 1; }

## make plots
echo -e "\\n=== make plots"
Rscript --vanilla "${SCRIPT_B}" "${PATIENT}" "${PATIENT}.qualityinfo.txt" "${MUTATIONFILE}" || { echo "ERROR: ${SCRIPT_B} FAILED"; exit 1; }

## make coverage histograms
echo -e "\\n=== make coverage histograms"
Rscript --vanilla "${SCRIPT_C}" "${CONV}" "${PATIENT}" ./ "${PATIENT}_qualplots/libraryQuality" || { echo "ERROR: ${SCRIPT_C} FAILED"; exit 1; }

## make TERT coverage plots
echo -e "\\n=== make TERT coverage plots"
python "${SCRIPT_D}" "${BAMPATH}/${PATIENT}" "${CONV}" "${PATIENT}" "${PATIENT}_qualplots/VAFPatterns" || { echo "ERROR: ${SCRIPT_D}  FAILED"; exit 1; }

## remove intermediate files
rm -f "${PATIENT}.qualityinfo.tmp"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
