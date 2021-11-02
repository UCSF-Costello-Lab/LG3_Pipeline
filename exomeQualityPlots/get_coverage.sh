#!/bin/bash    

###  Requred  BEDTOOLS=/home/shared/cbc/software_cbc/bedtools2-2.26.0/bin/bedtools
GENOME=/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.chrom.sizes
echo -n "Using "
${BEDTOOLS:?} --version
 
echo "Target bed path is ${bedpath:?}"
echo "Assuming data is coordinate sorted!"

for BAM in "${bampath:?}"/*.recal.bam
do
	echo "Processing BAM ${BAM} ... "
	 B=$(basename "${BAM}")
    output=${B}.hist
### Added by Ivan -g $GENOME to avoid ERROR message about chrM
    "${BEDTOOLS:?}" coverage -g "${GENOME:?}" -hist -sorted -b "${BAM}" -a "${bedpath}" | grep ^all > "${output}" || { echo "ERROR: bedtools failed!"; exit 1; }
	echo "Done! Output is in ${output}"
	wc -l "${output}"
done

echo "Bedtools finished!"
