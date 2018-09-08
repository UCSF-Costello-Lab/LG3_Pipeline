#!/bin/bash
#
##
### Find the mutation contexts and rates
###
### path/to/MutContext.sh </path/to/example.mutations> </path/to/example.mutect.wig> <Output Prefix>
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

mutsfile=$1
wigfile=$2
prefix=$3

PYTHON=/opt/local/bin/python
WIGFIXER="/home/jocostello/shared/LG3_Pipeline/scripts/mutect_wig_to_bed.py"
BEDTOOLS="/opt/BEDTools/BEDTools-2.16.2/bin/bedtools"
ANNO_AGILENT="/home/jocostello/shared/LG3_Pipeline/resources/Agilent_SureSelect_HumanAllExon50Mb.exonic_and_splicing.bed"
CALCULATE="/home/jocostello/shared/LG3_Pipeline/scripts/CalculateMutationRates.py"
GENOME="/home/jocostello/shared/LG3_Pipeline/resources/hg19.2bit"

export PYTHONPATH=/songlab/cmclean/code/vendor/Python-2.7.2:/home/jssong/lib/:/opt/ghmm/lib/python2.6/site-packages:/opt/local/lib/python2.6/site-packages/:/songlab/cmclean/code/py/:/home/jocostello/shared/LG3_Pipeline/
export PATH=${PATH}:/songlab/cmclean/bin/x86_64

if [ ! -e "${prefix}.mutation_context" ]; then
	echo "[MutContext] Converting MuTect WIG to BED3..."
	$PYTHON $WIGFIXER "$wigfile" > "${prefix}.temp.bed" || { echo "Conversion failed"; exit 1; }

	echo "[MutContext] Sort and merge BED..."
	$BEDTOOLS sort -i "${prefix}.temp.bed" > "${prefix}.temp.sorted.bed" || { echo "Sorting BED failed"; exit 1; }
	$BEDTOOLS merge -i "${prefix}.temp.sorted.bed" > "${prefix}.temp.sorted.merged.bed" || { echo "Merging BED failed"; exit 1; }

	rm -f "${prefix}.temp.bed"

	echo "[MutContext] Intersect MuTect BED with Agilent exonic and splicing BED..."
	$BEDTOOLS intersect \
		-a "${prefix}.temp.sorted.merged.bed" \
		-b $ANNO_AGILENT \
		> "${prefix}.temp.callable_space.bed" || { echo "Intersecting BEDs failed"; exit 1; }

	rm -f "${prefix}.temp.sorted.bed"
	rm -f "${prefix}.temp.sorted.merged.bed"

	echo "[MutContext] Enforcing judgement..."
	awk -F '\t' '$31=="yes"' \
		"${mutsfile}" \
		> "${prefix}.temp1.mutations" || { echo "Judgement failed"; exit 1; }

	echo "[MutContext] Removing offending columns..."
	awk -F '\t' '{for(i=1; i<=9; i++) {printf $i"\t";} printf "KEEP\t"; for(i=10; i<NF-2; i++) {printf $i"\t";} print $(NF-2)}' \
		"${prefix}.temp1.mutations" \
		> "${prefix}.temp2.mutations" || { echo "Removal failed"; exit 1; }

	rm -f "${prefix}.temp1.mutations"

	echo "[MutContext] Calculating mutation rates..."
	$PYTHON $CALCULATE \
		$GENOME \
		"${prefix}.temp.callable_space.bed" \
		"${prefix}.temp2.mutations" \
		"${prefix}.mutation_context" || { echo "Mutation rate failed"; exit 1; }

	rm -f "${prefix}.temp.callable_space.bed"
	rm -f "${prefix}.temp2.mutations"
fi

echo "[MutContext] Finished!"

