#!/bin/bash
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[0;33m'
NOC='\033[0m'

patient=$1
conv=/home/jocostello/shared/LG3_Pipeline/patient_ID_conversions.txt
project=LG3
WORKDIR=/costellolab/data1/jocostello/${project}/mutations/${patient}_mutect

if [ $# -eq 0 ]; then
	echo "ERROR: please specify patient!"
	exit 1
fi

echo -e "Checking MuTect output for ${YEL}${patient}${NOC}, project ${project}"
echo "conversion ${conv}"

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
OK="$GRN OK$NOC"
ERR="$RED missing$NOC"
	if [ -s "$OUT" ]; then
		echo -e "$ID $OK"
	else
		echo -e "$ID $ERR"
	fi

done < "${patient}.temp.conversions.txt"

## Delete patient specific conversion file
rm "${patient}.temp.conversions.txt"

