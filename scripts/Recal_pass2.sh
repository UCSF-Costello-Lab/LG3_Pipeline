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

##### Version of the pipeline without Base Qual. Recal! (for BAMS already recaled!)
#Fix the path so the QC scripts can output pdfs
#Both of these aren't necessary, but I'm leaving them here for future use
source /home/jocostello/.bashrc
PATH=/opt/R/R-latest/bin/R:$PATH

#Define resources and tools
JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=/home/jocostello/shared/LG3_Pipeline/tools/samtools-0.1.18/samtools
PICARD=/home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64
REF=/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.fa
THOUSAND=/home/jocostello/shared/LG3_Pipeline/resources/1000G_biallelic.indels.hg19.sorted.vcf
GATK=/home/jocostello/shared/LG3_Pipeline/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar

#Input variables
bamfiles=$1
patientID=$2
ilist=$3
TMP="/scratch/jocostello/${patientID}_tmp"
mkdir -p "$TMP"

echo "------------------------------------------------------"
echo "[Recal_pass2] Merging recalibrated files"
echo "------------------------------------------------------"
echo "[Recal_pass2] Merge Group: $patientID"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal_pass2] Exome:"$i}'
echo "------------------------------------------------------"

inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo "[Recal_pass2] Merge BAM files..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
	-jar $PICARD/MergeSamFiles.jar \
	"${inputs}" \
	OUTPUT="${patientID}.merged.bam" \
	SORT_ORDER=coordinate \
	TMP_DIR="${TMP}" \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=SILENT || { echo "Merge BAM files failed"; exit 1; }

echo "[Recal_pass2] Index new BAM file..."
$SAMTOOLS index "${patientID}.merged.bam" || { echo "First indexing failed"; exit 1; }

echo "[Recal_pass2] Create intervals for indel detection..."
$JAVA -Xmx4g -Djava.io.tmpdir="${TMP}" \
	-jar $GATK \
	--analysis_type RealignerTargetCreator \
	--reference_sequence $REF \
	--known $THOUSAND \
	--num_threads 6 \
	--logging_level WARN \
	--input_file "${patientID}.merged.bam" \
	--out "${patientID}.merged.intervals" || { echo "Interval creation failed"; exit 1; }

echo "[Recal_pass2] Indel realignment..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
	-jar $GATK \
	--analysis_type IndelRealigner \
	--reference_sequence $REF \
	--knownAlleles $THOUSAND \
	--logging_level WARN \
	--consensusDeterminationModel USE_READS \
	--input_file "${patientID}.merged.bam" \
	--targetIntervals "${patientID}.merged.intervals" \
	--out "${patientID}.merged.realigned.bam" || { echo "Indel realignment failed"; exit 1; }

rm -f "${patientID}.merged.bam"
rm -f "${patientID}.merged.bam.bai"
rm -f "${patientID}.merged.intervals"

echo "[Recal_pass2] Fix mate information..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
	-jar $PICARD/FixMateInformation.jar \
	INPUT="${patientID}.merged.realigned.bam" \
	OUTPUT="${patientID}.merged.realigned.mateFixed.bam" \
	SORT_ORDER=coordinate \
	TMP_DIR="${TMP}" \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=SILENT || { echo "Verify mate information failed"; exit 1; } 

rm -f "${patientID}.merged.realigned.bam"
rm -f "${patientID}.merged.realigned.bai"

echo "[Recal_pass2] Mark duplicates..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
	-jar $PICARD/MarkDuplicates.jar \
	INPUT="${patientID}.merged.realigned.mateFixed.bam" \
	OUTPUT="${patientID}.merged.realigned.rmDups.bam" \
	METRICS_FILE="${patientID}.merged.realigned.mateFixed.metrics" \
	REMOVE_DUPLICATES=TRUE \
	TMP_DIR="${TMP}" \
	VERBOSITY=WARNING \
	QUIET=true \
	VALIDATION_STRINGENCY=LENIENT || { echo "Mark duplicates failed"; exit 1; }

rm -f "${patientID}.merged.realigned.mateFixed.bam"

echo "[Recal_pass2] Index BAM file..."
$SAMTOOLS index "${patientID}.merged.realigned.rmDups.bam" || { echo "Second indexing failed"; exit 1; } 

echo "[Recal_pass2] Split BAM files..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" -jar $GATK \
	--analysis_type SplitSamFile \
	--reference_sequence $REF \
	--logging_level WARN \
	--input_file "${patientID}.merged.realigned.rmDups.bam" \
	--outputRoot temp_ || { echo "Splitting BAM files failed"; exit 1; }

rm -f "${patientID}.merged.realigned.rmDups.bam"
rm -f "${patientID}.merged.realigned.rmDups.bam.bai"
rm -f "${patientID}.merged.realigned.rmDups.bai"

for i in temp_*.bam
do
	base=${i##temp_}
	base=${base%%.bam}
	echo "[Recal_pass2] Splitting off $base..."
	$SAMTOOLS sort "$i" "${base}.bwa.realigned.rmDups" || { echo "Sorting $base failed"; exit 1; }
	$SAMTOOLS index "${base}.bwa.realigned.rmDups.bam" || { echo "Indexing $base failed"; exit 1; }	
	rm -f "$i"
done

echo "[Recal_pass2] Finished!"
echo "------------------------------------------------------"

echo "[QC] Quality Control"
for i in *.bwa.realigned.rmDups.bam
do
	echo "------------------------------------------------------"
	base=${i%%.bwa.realigned.rmDups.bam}
	echo "[QC] $base"

	echo "[QC] Calculate flag statistics..."
	$SAMTOOLS flagstat "$i" > "${base}.bwa.realigned.rmDups.flagstat" 2>&1

	echo "[QC] Calculate hybrid selection metrics..."
	$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
		-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/CalculateHsMetrics.jar \
		BAIT_INTERVALS="${ilist}" \
		TARGET_INTERVALS="${ilist}" \
		INPUT="$i" \
		OUTPUT="${base}.bwa.realigned.rmDups.hybrid_selection_metrics" \
		TMP_DIR="${TMP}" \
		VERBOSITY=WARNING \
		QUIET=true \
		VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

	echo "[QC] Collect multiple QC metrics..."
	$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
		-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/CollectMultipleMetrics.jar \
		INPUT="$i" \
		OUTPUT="${base}.bwa.realigned.rmDups" \
		REFERENCE_SEQUENCE=${REF} \
		TMP_DIR="${TMP}" \
		VERBOSITY=WARNING \
		QUIET=true \
		VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }
	echo "------------------------------------------------------"
done

echo "[QC] Finished!"
echo "-------------------------------------------------"

