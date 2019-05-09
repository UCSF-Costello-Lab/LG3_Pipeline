#!/bin/bash

source "${LG3_HOME:?}/scripts/utils.sh"

echo "Input:"
echo "- LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:?}"
echo "- PROJECT=${PROJECT:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- CONV=${CONV:?}"


## Pull out patient specific conversion info
grep -P "\\t${PATIENT}\\t" "${CONV}" | tr -d '\r' > "${PATIENT}.temp.conversions.txt"

PCFG=${PATIENT}.pindel.cfg
rm -f "${PCFG}"

while IFS=$'\t' read -r ID _ _ SAMP
do
	SIZE=$(grep MEDIAN_INSERT_SIZE -A1 "${LG3_OUTPUT_ROOT}/${PROJECT}/exomes_recal/${PATIENT}/${ID}.${RECAL_BAM_EXT}".*insert_size_metrics | cut -f1 | tail -n +2)
	BAM="${LG3_OUTPUT_ROOT}/${PROJECT}/exomes_recal/${PATIENT}/${ID}.${RECAL_BAM_EXT}.bam"
	if [ ! -r "${BAM}" ]; then
		error "Can't read ${BAM}!"
	fi
	echo -e "${BAM}\\t${SIZE}\\t${PATIENT}_${SAMP}" >> "${PCFG}"
done < "${PATIENT}.temp.conversions.txt"
rm "${PATIENT}.temp.conversions.txt"

echo "Pindel config file"
wc -l "${PCFG}"
cat "${PCFG}"

