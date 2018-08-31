#!/bin/bash
#
##
### Annotate an example.annotated.mutations file with RNA-seq data
###
### path/to/AnnotateRNA.sh </path/to/example.annotated.mutations> </path/to/RNA.bam> <Output Prefix>
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

mutsfile=$1
bamfile=$2
prefix=$3

PYTHON=/usr/bin/python
BEDMAKER="/home/jocostello/shared/LG3_Pipeline/scripts/annotation_BED_forRNA.py"
SAMTOOLS=/home/jocostello/shared/LG3_Pipeline/tools/samtools-0.1.12a/samtools
RNAANNO="/home/jocostello/shared/LG3_Pipeline/scripts/annotation_RNA.py"

if [ ! -e "${prefix}.annotated.withRNA.mutations" ]; then
	echo "[Annotate-RNA] Generate BED file..."
	$PYTHON $BEDMAKER \
		"${mutsfile}" \
		> "${prefix}.temp.bed" || { echo "BED creation failed"; exit 1; }

	echo "[Annotate-RNA] Generate pileup from RNA-seq data..."
	$SAMTOOLS pileup \
		-l "${prefix}.temp.bed" \
		"$bamfile" \
		> "${prefix}.temp.pileup" || { echo "Pileup creation failed"; exit 1; }

	echo "[Annotate-RNA] Add RNA-seq data..."
	$PYTHON $RNAANNO \
		"${mutsfile}" \
		"${prefix}.temp.pileup" \
		> "${prefix}.annotated.withRNA.mutations" || { echo "RNA annotation failed"; exit 1; }

	echo "[Annotate-RNA] Clean up..."
	rm -f "${prefix}.temp.bed"
	rm -f "${prefix}.temp.pileup"
fi

echo "[Annotate-RNA] Finished!"
