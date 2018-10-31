#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
EMAIL=${EMAIL:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_INPUT_ROOT=$LG3_INPUT_ROOT"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- EMAIL=$EMAIL"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
fi


QSUB_ENVVARS="LG3_HOME=${LG3_HOME},LG3_INPUT_ROOT=${LG3_INPUT_ROOT},LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT},EMAIL=${EMAIL}"
QSUB_OPTS="${QSUB_OPTS} -d ${PWD:?}"

## Override the qsub email address?
if [[ -n ${EMAIL} ]]; then
  QSUB_OPTS="${QSUB_OPTS} -M ${EMAIL}"
fi

echo "Qsub extras:"
echo "- QSUB_OPTS=${QSUB_OPTS}"
echo "- QSUB_ENVVARS=${QSUB_ENVVARS}"


### Input
PATIENT=$1
CONV=$2
PROJECT=$3
echo "Input:"
echo "- PROJECT=${PROJECT:?}"
echo "- CONV=${CONV:?}"
echo "- PATIENT=${PATIENT:?}"
[[ -f "$CONV" ]] || error "File not found: ${CONV}"

if [ $# -ne 3 ]; then
    error "Please specify patient, CONV file and project!"
fi

## References
CONFIG=${LG3_HOME}/FilterMutations/mutationConfig.cfg
INTERVAL=${LG3_HOME}/resources/All_exome_targets.extended_200bp.interval_list
echo "References:"
echo "- CONFIG=${CONFIG:?}"
echo "- INTERVAL=${INTERVAL:?}"
[[ -f "$CONFIG" ]] || error "File not found: ${CONFIG}"
[[ -f "$INTERVAL" ]] || error "File not found: ${INTERVAL}"


## Software
PBS=${LG3_HOME}/MutDet_TvsN.pbs
[[ -f "$PBS" ]] || error "File not found or not executable: ${PBS}"

WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT:?}/mutations/${PATIENT}_mutect
mkdir -p "${WORKDIR}" || error "Can't create scratch directory ${WORKDIR}"

XMX=Xmx8g

echo "Patient information inferred from PATIENT and CONV:"

## Pull out patient specific conversion info
grep -w "${PATIENT}" "${CONV}" | tr -d '\r' > "${PATIENT}.temp.conversions.txt"

## Get normal ID
while IFS=$'\t' read -r ID _ _ SAMP
do
        if [ "$SAMP" = "Normal" ]; then
                normid=${ID}
                break
        fi
done < "${PATIENT}.temp.conversions.txt"

echo "- normid='${normid:?}'"

## Cycle through tumors and submit MUTECT jobs
while IFS=$'\t' read -r ID _ _ SAMP
do
        if [ "$SAMP" = "Normal" ]; then
                continue
        elif [ "${SAMP:0:2}" = "ML" ]; then
                samp_label="ML"
        elif [ "${SAMP:0:3}" = "GBM" ]; then
                samp_label="GBM"
        elif [ "${SAMP:0:3}" = "Pri" ]; then
                samp_label="TUM"
        elif [ "${SAMP:0:3}" = "Tum" ]; then
                samp_label="TUM"
        elif [ "${SAMP:0:11}" = "Recurrence1" ]; then
                samp_label="REC1"
        elif [ "${SAMP:0:11}" = "Recurrence2" ]; then
                samp_label="REC2"
        elif [ "${SAMP:0:11}" = "Recurrence3" ]; then
                samp_label="REC3"
        elif [ "${SAMP:0:5}" == "tumor" ]; then
                samp_label="unkTUM"
        else
                samp_label="TUM"
        fi

        echo "- ID='${ID:?}'"
        echo "- samp_label='${samp_label:?}'"
	
        ## Expected output:
        OUT=$WORKDIR/${PATIENT}.NOR-${normid}__${samp_label}-${ID}.annotated.mutations
        if [ -s "$OUT" ]; then
                echo "WARNING: file $OUT exists, skipping this job ... "
        else
                # shellcheck disable=SC2086
                qsub ${QSUB_OPTS} -N "Mut_${PATIENT}" -v "${QSUB_ENVVARS},PROJECT=${PROJECT},NORMAL=${normid},TUMOR=${ID},TYPE=${samp_label},PATIENT=${PATIENT},CONFIG=$CONFIG,INTERVAL=$INTERVAL,WORKDIR=$WORKDIR,XMX=$XMX" "$PBS"
        fi

done < "${PATIENT}.temp.conversions.txt"

## Delete PATIENT specific conversion file
rm "${PATIENT}.temp.conversions.txt"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
