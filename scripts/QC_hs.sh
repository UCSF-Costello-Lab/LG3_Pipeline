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
### https://broadinstitute.github.io/picard/picard-metric-definitions.html#HsMetrics

source /home/jocostello/.bashrc
DIR=/costellolab/data1/jocostello/LG3/exomes_recal

JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
#Input variables
#bamfiles=$1
patientID=$1
ilist=$2
shift
shift

TMP="/scratch/jocostello/${patientID}_tmp"
mkdir -p $TMP

echo "------------------------------------------------------"
date
echo "------------------------------------------------------"
echo "[QC] Patient ID:" $patientID
echo "[QC] ILIST :" $ilist
#echo $bamfiles | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

#inputs=$(echo $bamfiles | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

cd $DIR/$patientID
echo "[QC] Calculate hybrid selection metrics..."
for i in $@
do
	echo "------------------------------------------------------"
	base=${i%%.bwa.realigned.rmDups.recal.bam}
	echo "[QC]" Sample: $base

	$JAVA -Xmx16g -Djava.io.tmpdir=${TMP} \
		-jar /home/jocostello/shared/LG3_Pipeline/tools/picard-tools-1.64/CalculateHsMetrics.jar \
		BAIT_INTERVALS=${ilist} \
		TARGET_INTERVALS=${ilist} \
		INPUT=$i \
		OUTPUT=${base}.bwa.realigned.rmDups.recal.HS_metrics \
		TMP_DIR=${TMP} \
		VERBOSITY=WARNING \
		QUIET=true \
		VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

done

echo -n "[QC] Finished! "
date
echo "-------------------------------------------------"

