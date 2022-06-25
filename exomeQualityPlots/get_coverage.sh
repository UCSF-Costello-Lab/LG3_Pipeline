#!/bin/bash    
#PBS -e _QC2_${PATIENT}.err
#PBS -o _QC2_${PATIENT}.out
#PBS -l nodes=1:ppn=2,vmem=200gb
#PBS -l walltime=7-00:00:00
#PBS -l mem=200gb
#PBS -m ae

# shellcheck source=scripts/utils.sh
source "${LG3_HOME:?}/scripts/utils.sh"
source_lg3_conf

###  Requred  BEDTOOLS=/home/shared/cbc/software_cbc/bedtools2-2.26.0/bin/bedtools
GENOME=/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.chrom.sizes
#module load bedtools2/2.30.0
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
    "${BEDTOOLS:?}" coverage -g "${GENOME:?}" -hist -sorted -b "${BAM}" -a "${bedpath}" | grep ^all > "${output}" || { error "ERROR: bedtools failed!"; }
	echo "Done! Output is in ${output}"
	wc -l "${output}"
done

echo "Bedtools finished!"
