#!/bin/bash
PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

echo "Launching Python script..."
echo "LG3_HOME = ${LG3_HOME}"
echo "LG3_OUTPUT_ROOT = ${LG3_OUTPUT_ROOT}"
echo "PROJECT = ${PROJECT}"
echo "PATIENT = ${PATIENT}"
echo "CONV = ${CONV}"
echo "BAMPATH = ${BAMPATH}"
echo "MUTATIONFILE = ${MUTATIONFILE}"

SCRIPT_A=${LG3_HOME}/scripts/annotate_mutations_from_bam_vSH_withstrand.py
[[ -f "${SCRIPT_A}" ]] || { echo "ERROR: File not found: ${SCRIPT_A}"; exit 1; }

WDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/QC_plots/${PATIENT}
mkdir -p "${WDIR}"
cd "${WDIR}" || { echo "ERROR: cd into ${WDIR} failed!"; exit 1; }

## run annotation code
python "${SCRIPT_A}" "${MUTATIONFILE}" "${CONV}" "${PATIENT}" "${PROJECT}" "${BAMPATH}" || { echo "ERROR: ${SCRIPT_A} failed"; exit 1; }

## remove intermediate files
rm -f "${PATIENT}.snvs."*Q*.txt

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
