#!/bin/bash
#
##
### Post alignment 
###
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=/home/jocostello/shared/LG3_Pipeline/tools/samtools-0.1.18/samtools
pl="Illumina"
pu="Exome"

prefix=$1
TMP="/scratch/jocostello/$prefix/tmp"
mkdir -p "$TMP"

echo "-------------------------------------------------"
echo "[Align] Post alignment!"
echo "-------------------------------------------------"
echo "[Align] Prefix: $prefix"
echo "-------------------------------------------------"

SAM=${prefix}.bwa.sam
if [ ! -f "$SAM" ]; then
	echo "ERROR: Can't open $SAM! STOP"
	exit 1
fi


echo "[Align] Verify mate information..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
	-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/FixMateInformation.jar \
	INPUT="$SAM" \
	OUTPUT="${prefix}.bwa.mateFixed.sam" \
	TMP_DIR="${TMP}" \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=SILENT || { echo "Verify mate information failed"; exit 1; } 

echo "[Align] Coordinate-sort and enforce read group assignments..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
	-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/AddOrReplaceReadGroups.jar \
	INPUT="${prefix}.bwa.mateFixed.sam" \
	OUTPUT="${prefix}.bwa.sorted.sam" \
	SORT_ORDER=coordinate \
	RGID="$prefix" \
	RGLB="$prefix" \
	RGPL=$pl \
	RGPU=$pu \
	RGSM="$prefix" \
	TMP_DIR="${TMP}" \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=LENIENT || { echo "Sort failed"; exit 1; }

echo "[Align] Convert SAM to BAM..."
$SAMTOOLS view -bS "${prefix}.bwa.sorted.sam" > "${prefix}.trim.bwa.sorted.bam" || { echo "BAM conversion failed"; exit 1; }

echo "[Align] Index the BAM file..."
$SAMTOOLS index "${prefix}.trim.bwa.sorted.bam" || { echo "BAM indexing failed"; exit 1; }

echo "[Align] Clean up..."
rm -f "__${prefix}"*.log
rm -f "${prefix}"*.sai
rm -f "${prefix}"*.sam
echo "[Align] Finished!"

echo "-------------------------------------------------"
echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat "${prefix}.trim.bwa.sorted.bam" > "${prefix}.trim.bwa.sorted.flagstat" 2>&1
echo "[QC] Finished!"
echo "-------------------------------------------------"
rm -rf "$TMP"
