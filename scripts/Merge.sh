#!/bin/bash
#
## Merge BAM files and enforce read group assignments
#
## Usage: /path/to/Merge.sh <bamfiles> <prefix> 
#
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#
source /home/jocostello/.bashrc
PATH=/opt/R/R-latest/bin/R:$PATH

#Define resources and tools
TMP="/scratch"
pl="Illumina"
pu="Exome"
JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
PICARD=/home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64
SAMTOOLS=/home/jocostello/shared/LG3_Pipeline/tools/samtools-0.1.18/samtools

#Input variables
bamfiles=$1
prefix=$2

echo "------------------------------------------------------"
echo "[Merge] Merge technical replicates"
echo "------------------------------------------------------"
echo "[Merge] Merge Group:" $prefix
echo $bamfiles | awk -F ":" '{for (i=1; i<=NF; i++) print "[Merge] Exome:"$i}'
echo "------------------------------------------------------"

inputs=$(echo $bamfiles | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo "[Merge] Merge BAM files..."
$JAVA -Xmx8g -Djava.io.tmpdir=${TMP} \
	-jar $PICARD/MergeSamFiles.jar \
	${inputs} \
	OUTPUT=${prefix}.merged.bam \
	SORT_ORDER=coordinate \
	TMP_DIR=${TMP} \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=SILENT || { echo "Merge BAM files failed"; exit 1; }

echo "[Merge] Index new BAM file..."
$SAMTOOLS index ${prefix}.merged.bam || { echo "First indexing failed"; exit 1; }


echo "[Merge] Coordinate-sort and enforce read group assignments..."
$JAVA -Xmx2g -Djava.io.tmpdir=${TMP} \
	-jar $PICARD/AddOrReplaceReadGroups.jar \
	INPUT=${prefix}.merged.bam \
	OUTPUT=${prefix}.merged.sorted.sam \
	SORT_ORDER=coordinate \
	RGID=$prefix \
	RGLB=$prefix \
	RGPL=$pl \
	RGPU=$pu \
	RGSM=$prefix \
	TMP_DIR=${TMP} \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=LENIENT || { echo "Sort failed"; exit 1; }

rm -f ${prefix}.merged.bam
rm -f ${prefix}.merged.bam.bai

echo "[Merge] Convert SAM to BAM..."
$SAMTOOLS view -bS ${prefix}.merged.sorted.sam > ${prefix}.merged.sorted.bam || { echo "BAM conversion failed"; exit 1; }

rm -f ${prefix}.merged.sorted.sam

echo "[Merge] Index the BAM file..."
$SAMTOOLS index ${prefix}.merged.sorted.bam || { echo "BAM indexing failed"; exit 1; }


echo "[Merge] Finished!"
echo "------------------------------------------------------"
