#!/bin/bash    
PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

BEDTOOLS=/home/shared/cbc/software_cbc/bedtools2-2.26.0/bin/bedtools
GENOME=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.chrom.sizes
echo -n "Using "
$BEDTOOLS --version

WDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/QC_plots/${PATIENT}
mkdir -p "${WDIR}"
cd "${WDIR}" || { echo "ERROR: cd into ${WDIR} failed!"; exit 1; }

echo "Target bed path is ${BEDPATH}"
echo "Assuming data is coordinate sorted!"

for entry in ${BAMPATH}/*.recal.bam
do
	echo "Processing BAM $entry ... "
	B=$(basename "$entry")
   output=$B.hist
	### Added by Ivan -g $GENOME to avoid ERROR message about chrM
   ${BEDTOOLS} coverage -g ${GENOME} -hist -sorted -b "$entry" -a "${BEDPATH}" | grep ^all > "$output" || { echo "ERROR: bedtools failed!"; exit 1; }
	echo "Done! Output: ${WDIR}/${output}"
	wc -l "$output"
done

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
