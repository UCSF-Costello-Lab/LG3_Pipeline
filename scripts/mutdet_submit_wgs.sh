#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
PROJECT=${PROJECT:?}
EMAIL=${EMAIL:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "EMAIL=${EMAIL}"
  echo "LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi



patient=$1
conv=$2
project=$3
XMX=Xmx32g
WORKDIR=${LG3_OUTPUT_ROOT}/${project:?}/mutations/${patient}_mutect_wgs

if [ $# -ne 3 ]; then
        echo "ERROR: please specify patient, conversion file and project!"
        exit 1
fi

CONFIG=${LG3_HOME}/FilterMutations/mutationConfig.cfg
INTERVAL=${LG3_HOME}/resources/WG_hg19-ENCFF001TDO.bed
PBS=${LG3_HOME}/MutDet_TvsN.pbs

## Pull out patient specific conversion info
grep -w "${patient}" "${conv}" > "${patient}.temp.conversions.txt"

## Get normal ID
while IFS=$'\t' read -r ID _ _ SAMP
do
        if [ "$SAMP" = "Normal" ]; then
                normid="${ID}"
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
                echo "qsub -M ${EMAIL:?} -N ${patient}.mut -v PROJECT=${project},NORMAL=${normid},TUMOR=${ID},TYPE=${samp_label},PATIENT=${patient},CONFIG=$CONFIG,INTERVAL=$INTERVAL $PBS"
                qsub -M "${EMAIL:?}" -N "${patient}.mut" -v "PROJECT=${project},NORMAL=${normid},TUMOR=${ID},TYPE=${samp_label},PATIENT=${patient},CONFIG=$CONFIG,INTERVAL=$INTERVAL,XMX=$XMX,WORKDIR=$WORKDIR" "$PBS"
        fi

done < "${patient}.temp.conversions.txt"

## Delete patient specific conversion file
rm "${patient}.temp.conversions.txt"

