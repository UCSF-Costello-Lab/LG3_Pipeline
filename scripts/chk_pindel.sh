#!/bin/bash
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[0;33m'
NOC='\033[0m'
OK="$GRN OK$NOC"
ERR="$RED missing$NOC"

if [ $# -eq 0 ]; then
	echo "ERROR: please specify patient!"
	exit 1
fi
project=LG3
echo -e "Checking Pindel output for project ${project}"

for patient in $@
do
	WORKDIR=/costellolab/data1/jocostello/${project}/pindel/${patient}_pindel
	## Expected output:
	OUT=$WORKDIR/${patient}.indels.filtered.anno.txt
	if [ -s "$OUT" ]; then
		echo -e ${patient} $OK
	else
		echo -e ${patient} $ERR
	fi
done
