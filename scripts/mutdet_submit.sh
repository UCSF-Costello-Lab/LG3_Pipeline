#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
LG3_INPUT_ROOT=${LG3_INPUT_ROOT:-${LG3_OUTPUT_ROOT}}
PROJECT=${PROJECT:?}
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
QSUB_OPTS="-d ${PWD:?}"

## Override the qsub email address?
if [[ -n ${EMAIL} ]]; then
  QSUB_OPTS="${QSUB_OPTS} -M ${EMAIL}"
fi

echo "Qsub extras:"
echo "- QSUB_OPTS=${QSUB_OPTS}"
echo "- QSUB_ENVVARS=${QSUB_ENVVARS}"


### Input
patient=$1
conv=$2
PROJECT=$3
echo "Input:"
echo "- patient=${patient:?}"
echo "- conv=${conv:?}"
echo "- PROJECT=${PROJECT:?}"
[[ -f "$conv" ]] || { echo "File not found: ${conv}"; exit 1; }

if [ $# -ne 3 ]; then
        echo "ERROR: please specify patient, conversion file and project!"
        exit 1
fi

## References
CONFIG=${LG3_HOME}/FilterMutations/mutationConfig.cfg
INTERVAL=${LG3_HOME}/resources/All_exome_targets.extended_200bp.interval_list
echo "References:"
echo "- CONFIG=${CONFIG:?}"
echo "- INTERVAL=${INTERVAL:?}"
[[ -f "$CONFIG" ]] || { echo "File not found: ${CONFIG}"; exit 1; }
[[ -f "$INTERVAL" ]] || { echo "File not found: ${INTERVAL}"; exit 1; }


## Software
PBS=${LG3_HOME}/MutDet_TvsN.pbs
[[ -f "$PBS" ]] || { echo "File not found or not executable: ${PBS}"; exit 1; }

WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT:?}/mutations/${patient}_mutect
mkdir -p "${WORKDIR}" || { echo "Can't create scratch directory ${WORKDIR}"; exit 1; }

XMX=Xmx8g

## Pull out patient specific conversion info
grep -w "${patient}" "${conv}" > "${patient}.temp.conversions.txt"

## Get normal ID
while IFS=$'\t' read -r ID _ _ SAMP
do
        if [ "$SAMP" = "Normal" ]; then
                normid=${ID}
                break
        fi
done < "${patient}.temp.conversions.txt"

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
        ## Expected output:
        OUT=$WORKDIR/${patient}.NOR-${normid}__${samp_label}-${ID}.annotated.mutations
        if [ -s "$OUT" ]; then
                echo "WARNING: file $OUT exists, skipping this job ... "
        else
                echo "qsub ${QSUB_OPTS} -N ${patient}.mut -v ${QSUB_ENVVARS},PROJECT=${PROJECT},NORMAL=${normid},TUMOR=${ID},TYPE=${samp_label},PATIENT=${patient},CONFIG=$CONFIG,INTERVAL=$INTERVAL $PBS"
                # shellcheck disable=SC2086
                qsub ${QSUB_OPTS} -N "${patient}.mut" -v "${QSUB_ENVVARS},PROJECT=${PROJECT},NORMAL=${normid},TUMOR=${ID},TYPE=${samp_label},PATIENT=${patient},CONFIG=$CONFIG,INTERVAL=$INTERVAL,WORKDIR=$WORKDIR,XMX=$XMX" "$PBS"
        fi

done < "${patient}.temp.conversions.txt"

## Delete patient specific conversion file
rm "${patient}.temp.conversions.txt"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
