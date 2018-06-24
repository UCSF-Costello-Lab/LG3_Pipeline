#!/bin/bash
#
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

source /home/jocostello/.bashrc

#Define resources and tools
JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=/home/jocostello/shared/LG3_Pipeline/tools/samtools-0.1.18/samtools
REF="/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.fa"

#Input variables
bamfile=$1
PREF=$(basename $bamfile .bam)
Z=${PREF%%.*}
D=$(dirname $bamfile)
cd $D
ilist=$2
TMP="/scratch/jocostello/${Z}_tmp"
mkdir -p $TMP

echo "------------------------------------------------------"
echo "[Recal] QC after Base quality recalibration (WGS version)"
date
echo "------------------------------------------------------"

echo "[QC] Quality Control"
echo "------------------------------------------------------"
echo "[QC]" $bamfile

echo "[QC] Calculate flag statistics..."
$SAMTOOLS flagstat $bamfile > ${Z}.bwa.realigned.rmDups.recal.flagstat 2>&1

echo "[QC] Collect multiple QC metrics..."
$JAVA -Xmx16g -Djava.io.tmpdir=${TMP} \
	-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/CollectMultipleMetrics.jar \
	INPUT=$bamfile \
	OUTPUT=${Z}.bwa.realigned.rmDups.recal \
	REFERENCE_SEQUENCE=${REF} \
	TMP_DIR=${TMP} \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }
	echo "------------------------------------------------------"


echo -n "[QC] $Z Finished! "
date
echo "-------------------------------------------------"

