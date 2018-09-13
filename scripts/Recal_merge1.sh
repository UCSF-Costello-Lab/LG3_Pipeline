#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:1}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- SCRATCHDIR=$SCRATCHDIR"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
  echo "- ncores=$ncores"
fi


#
#Both of these aren't necessary, but I'm leaving them here for future use
echo "Recal starting with already merged BAM before realignment"
# shellcheck source=.bashrc
source "${LG3_HOME}/.bashrc"
PATH=/opt/R/R-latest/bin/R:$PATH

#Define resources and tools
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
REF="${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa"
THOUSAND="${LG3_HOME}/resources/1000G_biallelic.indels.hg19.sorted.vcf"
GATK="${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
DBSNP="${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf"

#Input variables
bamfiles=$1
patientID=$2
ilist=$3
TMP="${SCRATCHDIR}/${patientID}_tmp"
mkdir -p "$TMP"
#ilist2=${LG3_HOME}/resources/SeqCap_EZ_Exome_v3_capture.interval_list

echo "------------------------------------------------------"
echo "[Recal] BQ recal (after merge and create intervals !)"
date
echo "------------------------------------------------------"
echo "[Recal] Recalibration Group: $patientID"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

echo "[Recal] Merge BAM files... skipped!"

echo "[Recal] Create intervals for indel detection... skipped!"

echo "[Recal] Indel realignment..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
   -jar "$GATK" \
   --analysis_type IndelRealigner \
   --reference_sequence "$REF" \
   --knownAlleles "$THOUSAND" \
   --logging_level WARN \
   --consensusDeterminationModel USE_READS \
   --input_file "${patientID}.merged.bam" \
   --targetIntervals "${patientID}.merged.intervals" \
   --out "${patientID}.merged.realigned.bam" || { echo "Indel realignment failed"; exit 1; }

rm -f "${patientID}.merged.bam"
rm -f "${patientID}.merged.bam.bai"
rm -f "${patientID}.merged.intervals"

echo "[Recal] Fix mate information..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
   -jar "${LG3_HOME}/tools/picard-tools-1.64/FixMateInformation.jar" \
   INPUT="${patientID}.merged.realigned.bam" \
   OUTPUT="${patientID}.merged.realigned.mateFixed.bam" \
   SORT_ORDER=coordinate \
   TMP_DIR="${TMP}" \
   VERBOSITY=WARNING \
   QUIET=true \
   VALIDATION_STRINGENCY=SILENT || { echo "Verify mate information failed"; exit 1; }

rm -f "${patientID}.merged.realigned.bam"
rm -f "${patientID}.merged.realigned.bai"

echo "[Recal] Mark duplicates..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
   -jar "${LG3_HOME}/tools/picard-tools-1.64/MarkDuplicates.jar" \
   INPUT="${patientID}.merged.realigned.mateFixed.bam" \
   OUTPUT="${patientID}.merged.realigned.rmDups.bam" \
   METRICS_FILE="${patientID}.merged.realigned.mateFixed.metrics" \
   REMOVE_DUPLICATES=TRUE \
   TMP_DIR="${TMP}" \
   VERBOSITY=WARNING \
   QUIET=true \
   VALIDATION_STRINGENCY=LENIENT || { echo "Mark duplicates failed"; exit 1; }

rm -f "${patientID}.merged.realigned.mateFixed.bam"

echo "[Recal] Index BAM file..."
$SAMTOOLS index "${patientID}.merged.realigned.rmDups.bam" || { echo "Second indexing failed"; exit 1; }

### Job crushed at -Xmx8g, increase!
echo "[Recal] Base-quality recalibration: Count covariates..."
$JAVA -Xmx128g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type CountCovariates \
        --reference_sequence "$REF" \
        --knownSites "$DBSNP" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --covariate ReadGroupCovariate \
        --covariate QualityScoreCovariate \
        --covariate CycleCovariate \
        --covariate DinucCovariate \
        --covariate MappingQualityCovariate \
        --standard_covs \
        --input_file "${patientID}.merged.realigned.rmDups.bam" \
        --recal_file "${patientID}.merged.realigned.rmDups.csv" || { echo "CountCovariates failed"; exit 1; }

echo "[Recal] Base-quality recalibration: Table Recalibration..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type TableRecalibration \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --baq RECALCULATE \
        --recal_file "${patientID}.merged.realigned.rmDups.csv" \
        --input_file "${patientID}.merged.realigned.rmDups.bam" \
        --out "${patientID}.merged.realigned.rmDups.recal.bam" || { echo "TableRecalibration failed"; exit 1; }

rm -f "${patientID}.merged.realigned.rmDups.bam"
rm -f "${patientID}.merged.realigned.rmDups.bam.bai"
rm -f "${patientID}.merged.realigned.rmDups.csv"

echo "[Recal] Index BAM file..."
$SAMTOOLS index "${patientID}.merged.realigned.rmDups.recal.bam" || { echo "Third indexing failed"; exit 1; } 

echo "[Recal] Split BAM files..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type SplitSamFile \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --input_file "${patientID}.merged.realigned.rmDups.recal.bam" \
        --outputRoot temp_ || { echo "Splitting BAM files failed"; exit 1; }

rm -f "${patientID}.merged.realigned.rmDups.recal.bam"
rm -f "${patientID}.merged.realigned.rmDups.recal.bam.bai"
rm -f "${patientID}.merged.realigned.rmDups.recal.bai"

for i in temp_*.bam
do
        base=${i##temp_}
        base=${base%%.bam}
        echo "[Recal] Splitting off $base..."
        $SAMTOOLS sort "$i" "${base}.bwa.realigned.rmDups.recal" || { echo "Sorting $base failed"; exit 1; }
        $SAMTOOLS index "${base}.bwa.realigned.rmDups.recal.bam" || { echo "Indexing $base failed"; exit 1; }        
        rm -f "$i"
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
        echo "[QC] $base"

        echo "[QC] Calculate flag statistics..."
        $SAMTOOLS flagstat "$i" > "${base}.bwa.realigned.rmDups.recal.flagstat" 2>&1

        echo "[QC] Calculate hybrid selection metrics..."
        $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CalculateHsMetrics.jar" \
                BAIT_INTERVALS="${ilist}" \
                TARGET_INTERVALS="${ilist}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

        echo "[QC] Collect multiple QC metrics..."
        $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CollectMultipleMetrics.jar" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }
        echo "------------------------------------------------------"
done

echo -n "[QC] Finished! "
date
echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
