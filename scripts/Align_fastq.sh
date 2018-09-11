#!/bin/bash
#
##
### Align Illumina PE exome sequence data from two fastq files with BWA.
###
### /path/to/Align_fastq.sh <fastq1> <fastq2> <output prefix>
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

BWA=/home/jocostello/shared/LG3_Pipeline/tools/bwa-0.5.10/bwa
BWA_INDEX="/home/jocostello/shared/LG3_Pipeline/resources/bwa_indices/hg19.bwa"
JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=/home/jocostello/shared/LG3_Pipeline/tools/samtools-0.1.18/samtools
PYTHON=/usr/bin/python
pl="Illumina"
pu="Exome"

fastq1=$1
fastq2=$2
prefix=$3
TMP="/scratch/jocostello/$prefix/tmp"
mkdir -p "$TMP"

echo "-------------------------------------------------"
echo "[Align] BWA alignment!"
echo "-------------------------------------------------"
echo "[Align] Fastq file #1: $fastq1"
echo "[Align] Fastq file #2: $fastq2"
echo "[Align] Prefix: $prefix"
echo "[Align] BWA index: $BWA_INDEX"
echo "-------------------------------------------------"

#echo "[Align] Removing chastity filtered first-in-pair reads..."
#$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/removeQCgz.py "$fastq1" \
	#> "${prefix}.read1.QC.fastq" || { echo "Chastity filtering read1 failed"; exit 1; }
#
#echo "[Align] Removing chastity filtered second-in-pair reads..."
#$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/removeQCgz.py "$fastq2" \
	#> "${prefix}.read2.QC.fastq" || { echo "Chastity filtering read2 failed"; exit 1; }

zcat "$fastq1" > "${prefix}.read1.QC.fastq"
zcat "$fastq2" > "${prefix}.read2.QC.fastq"

echo "[Align] Align first-in-pair reads..."
$BWA aln -t 12 $BWA_INDEX "${prefix}.read1.QC.fastq" \
  > "${prefix}.read1.sai" 2> "__${prefix}_read1.log" || { echo "BWA alignment failed"; exit 1; }

echo "[Align] Align second-in-pair reads..."
$BWA aln -t 12 $BWA_INDEX "${prefix}.read2.QC.fastq" \
  > "${prefix}.read2.sai" 2> "__${prefix}_read2.log" || { echo "BWA alignment failed"; exit 1; }

echo "[Align] Pair aligned reads..."
$BWA sampe $BWA_INDEX "${prefix}.read1.sai" "${prefix}.read2.sai" \
  "${prefix}.read1.QC.fastq" "${prefix}.read2.QC.fastq" > "${prefix}.bwa.sam" 2>> "__${prefix}.sampe.log" || { echo "BWA sampe failed"; exit 1; }

rm -f "${prefix}.read1.QC.fastq"
rm -f "${prefix}.read2.QC.fastq"

echo "[Align] Verify mate information..."
$JAVA -Xmx2g -Djava.io.tmpdir="${TMP}" \
	-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/FixMateInformation.jar \
	INPUT="${prefix}.bwa.sam" \
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
