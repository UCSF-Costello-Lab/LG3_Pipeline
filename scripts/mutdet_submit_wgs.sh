#!/bin/bash

patient=$1
conv=$2
project=$3
XMX=Xmx32g
WORKDIR=/costellolab/data1/jocostello/${project}/mutations/${patient}_mutect_wgs

if [ $# -ne 3 ]; then
	echo "ERROR: please specify patient, conversion file and project!"
	exit 1
fi

CONFIG=/home/jocostello/shared/LG3_Pipeline/FilterMutations/mutationConfig.cfg
INTERVAL=/home/jocostello/shared/LG3_Pipeline/resources/WG_hg19-ENCFF001TDO.bed
PBS=/home/jocostello/shared/LG3_Pipeline/MutDet_TvsN.pbs

## Pull out patient specific conversion info
grep -w ${patient} ${conv} > ${patient}.temp.conversions.txt

## Get normal ID
while IFS=$'\t' read ID SF PAT SAMP
do
	if [ $SAMP = "Normal" ]; then
		normid=${ID}
		break
	fi
done < ${patient}.temp.conversions.txt

## Cycle through tumors and submit MUTECT jobs
while IFS=$'\t' read ID SF PAT SAMP
do
	if [ $SAMP = "Normal" ]; then
		continue
	elif [ ${SAMP:0:2} = "ML" ]; then
		samp_label="ML"
	elif [ ${SAMP:0:3} = "GBM" ]; then
		samp_label="GBM"
	elif [ ${SAMP:0:3} = "Pri" ]; then
		samp_label="TUM"
	elif [ ${SAMP:0:3} = "Tum" ]; then
		samp_label="TUM"
	elif [ ${SAMP:0:11} = "Recurrence1" ]; then
		samp_label="REC1"
	elif [ ${SAMP:0:11} = "Recurrence2" ]; then
		samp_label="REC2"
	elif [ ${SAMP:0:11} = "Recurrence3" ]; then
		samp_label="REC3"
        elif [ ${SAMP:0:5} == "tumor" ]; then
                samp_label="unkTUM"
	else
		samp_label="TUM"
	fi
	## Expected output:
	OUT=$WORKDIR/${patient}.NOR-${normid}__${samp_label}-${ID}.annotated.mutations
	if [ -s "$OUT" ]; then
		echo "WARNING: file $OUT exists, skipping this job ... "
	else
		echo "qsub -M ivan.smirnov@ucsf.edu -N ${patient}.mut -v PROJECT=${project},NORMAL=${normid},TUMOR=${ID},TYPE=${samp_label},PATIENT=${patient},CONFIG=$CONFIG,INTERVAL=$INTERVAL $PBS"
		qsub -M ivan.smirnov@ucsf.edu -N ${patient}.mut -v PROJECT=${project},NORMAL=${normid},TUMOR=${ID},TYPE=${samp_label},PATIENT=${patient},CONFIG=$CONFIG,INTERVAL=$INTERVAL,XMX=$XMX,WORKDIR=$WORKDIR $PBS
	fi

done <${patient}.temp.conversions.txt

## Delete patient specific conversion file
rm ${patient}.temp.conversions.txt

