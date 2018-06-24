#!/bin/bash
#
## Base quality recalibration, prep for indel detection, and quality control
#
## Usage: /path/to/Recal.sh <bamfiles> <patientID> <exome_kit.interval_list>
#
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

#Fix the path so the QC scripts can output pdfs
#Both of these aren't necessary, but I'm leaving them here for future use
source /home/jocostello/.bashrc
PATH=/opt/R/R-latest/bin/R:$PATH

#Define resources and tools
JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=/home/jocostello/shared/LG3_Pipeline/tools/samtools-0.1.18/samtools
REF="/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.fa"
THOUSAND="/home/jocostello/shared/LG3_Pipeline/resources/1000G_biallelic.indels.hg19.sorted.vcf"
GATK="/home/jocostello/shared/LG3_Pipeline/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
#RES="/home/jocostello/shared/LG3_Pipeline/tools/GenomeAnalysisTK-1.6-5-g557da77/resources/"
DBSNP="/home/jocostello/shared/LG3_Pipeline/resources/dbsnp_132.hg19.sorted.vcf"

#Input variables
bamfiles=$1
patientID=$2
ilist=$3
TMP="/scratch/jocostello/${patientID}_tmp"
mkdir -p $TMP
#ilist2=/home/jocostello/shared/LG3_Pipeline/resources/SeqCap_EZ_Exome_v3_capture.interval_list

echo "------------------------------------------------------"
echo "[Recal] BQ recal (after merge,realign,fixMate,rmDups!)"
date
echo "------------------------------------------------------"
echo "[Recal] Recalibration Group:" $patientID
echo $bamfiles | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

#echo "[Recal] Index BAM file..."
#$SAMTOOLS index ${patientID}.merged.realigned.rmDups.bam || { echo "Second indexing failed"; exit 1; } 

### Job crushed at -Xmx8g, increase!
echo "[Recal] Base-quality recalibration: Count covariates..."
$JAVA -Xmx128g -Djava.io.tmpdir=${TMP} -jar $GATK \
	--analysis_type CountCovariates \
	--reference_sequence $REF \
	--knownSites $DBSNP \
	--num_threads 8 \
	--logging_level WARN \
	--covariate ReadGroupCovariate \
	--covariate QualityScoreCovariate \
	--covariate CycleCovariate \
	--covariate DinucCovariate \
	--covariate MappingQualityCovariate \
	--standard_covs \
	--input_file ${patientID}.merged.realigned.rmDups.bam \
	--recal_file ${patientID}.merged.realigned.rmDups.csv || { echo "CountCovariates failed"; exit 1; }

echo "[Recal] Base-quality recalibration: Table Recalibration..."
$JAVA -Xmx16g -Djava.io.tmpdir=${TMP} -jar $GATK \
	--analysis_type TableRecalibration \
	--reference_sequence $REF \
	--logging_level WARN \
	--baq RECALCULATE \
	--recal_file ${patientID}.merged.realigned.rmDups.csv \
	--input_file ${patientID}.merged.realigned.rmDups.bam \
	--out ${patientID}.merged.realigned.rmDups.recal.bam || { echo "TableRecalibration failed"; exit 1; }

rm -f ${patientID}.merged.realigned.rmDups.bam
rm -f ${patientID}.merged.realigned.rmDups.bam.bai
rm -f ${patientID}.merged.realigned.rmDups.csv

echo "[Recal] Index BAM file..."
$SAMTOOLS index ${patientID}.merged.realigned.rmDups.recal.bam || { echo "Third indexing failed"; exit 1; } 

echo "[Recal] Split BAM files..."
$JAVA -Xmx16g -Djava.io.tmpdir=${TMP} -jar $GATK \
	--analysis_type SplitSamFile \
	--reference_sequence $REF \
	--logging_level WARN \
	--input_file ${patientID}.merged.realigned.rmDups.recal.bam \
	--outputRoot temp_ || { echo "Splitting BAM files failed"; exit 1; }

rm -f ${patientID}.merged.realigned.rmDups.recal.bam
rm -f ${patientID}.merged.realigned.rmDups.recal.bam.bai
rm -f ${patientID}.merged.realigned.rmDups.recal.bai

for i in temp_*.bam
do
	base=${i##temp_}
	base=${base%%.bam}
	echo "[Recal] Splitting off $base..."
	$SAMTOOLS sort $i ${base}.bwa.realigned.rmDups.recal || { echo "Sorting $base failed"; exit 1; }
	$SAMTOOLS index ${base}.bwa.realigned.rmDups.recal.bam || { echo "Indexing $base failed"; exit 1; }	
	rm -f $i
done

echo "------------------------------------------------------"
echo -n "[Recal] Finished! "
date
echo "------------------------------------------------------"

echo "[QC] Quality Control"
for i in *.bwa.realigned.rmDups.recal.bam
do
	echo "------------------------------------------------------"
	base=${i%%.bwa.realigned.rmDups.recal.bam}
	echo "[QC]" $base

	echo "[QC] Calculate flag statistics..."
	$SAMTOOLS flagstat $i > ${base}.bwa.realigned.rmDups.recal.flagstat 2>&1

	echo "[QC] Calculate hybrid selection metrics..."
	$JAVA -Xmx16g -Djava.io.tmpdir=${TMP} \
		-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/CalculateHsMetrics.jar \
		BAIT_INTERVALS=${ilist} \
		TARGET_INTERVALS=${ilist} \
		INPUT=$i \
		OUTPUT=${base}.bwa.realigned.rmDups.recal.hybrid_selection_metrics \
		TMP_DIR=${TMP} \
		VERBOSITY=WARNING \
		QUIET=true \
		VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

	echo "[QC] Collect multiple QC metrics..."
	$JAVA -Xmx16g -Djava.io.tmpdir=${TMP} \
		-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/CollectMultipleMetrics.jar \
		INPUT=$i \
		OUTPUT=${base}.bwa.realigned.rmDups.recal \
		REFERENCE_SEQUENCE=${REF} \
		TMP_DIR=${TMP} \
		VERBOSITY=WARNING \
		QUIET=true \
		VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }
	echo "------------------------------------------------------"
done

echo -n "[QC] Finished! "
date
echo "-------------------------------------------------"

