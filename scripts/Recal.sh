#!/bin/bash

# shellcheck source=scripts/utils.sh
source "${LG3_HOME}/scripts/utils.sh"

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
  echo "- ncores=$ncores"
fi


#
## Base quality recalibration, prep for indel detection, and quality control
#
## Usage: /path/to/Recal.sh <bamfiles> <patientID> <exome_kit.interval_list>
#
#

#Fix the path so the QC scripts can output pdfs
#Both of these aren't necessary, but I'm leaving them here for future use
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
TMP="${LG3_SCRATCH_ROOT}/$patientID"
mkdir -p "$TMP"

echo "------------------------------------------------------"
echo "[Recal] Base quality recalibration"
echo "------------------------------------------------------"
echo "[Recal] Recalibration Group: $patientID"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

## Construct string with one or more '-I "<bam>"' elements
inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT="$i" "}')

echo "[Recal] Merge BAM files..."
# shellcheck disable=SC2086
# Comment: Because how 'inputs' is created and used below
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/MergeSamFiles.jar" \
        ${inputs} \
        OUTPUT="${patientID}.merged.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "Merge BAM files failed"

echo "[Recal] Index new BAM file..."
$SAMTOOLS index "${patientID}.merged.bam" || error "First indexing failed"

echo "[Recal] Create intervals for indel detection..."
$JAVA -Xmx4g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type RealignerTargetCreator \
        --reference_sequence "$REF" \
        --known "$THOUSAND" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --input_file "${patientID}.merged.bam" \
        --out "${patientID}.merged.intervals" || error "Interval creation failed"

echo "[Recal] Indel realignment..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type IndelRealigner \
        --reference_sequence "$REF" \
        --knownAlleles "$THOUSAND" \
        --logging_level WARN \
        --consensusDeterminationModel USE_READS \
        --input_file "${patientID}.merged.bam" \
        --targetIntervals "${patientID}.merged.intervals" \
        --out "${patientID}.merged.realigned.bam" || error "Indel realignment failed"

rm -f "${patientID}.merged.bam"
rm -f "${patientID}.merged.bam.bai"
rm -f "${patientID}.merged.intervals"

echo "[Recal] Fix mate information..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/FixMateInformation.jar" \
        INPUT="${patientID}.merged.realigned.bam" \
        OUTPUT="${patientID}.merged.realigned.mateFixed.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || error "Verify mate information failed"

rm -f "${patientID}.merged.realigned.bam"
rm -f "${patientID}.merged.realigned.bai"

echo "[Recal] Mark duplicates..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/MarkDuplicates.jar" \
        INPUT="${patientID}.merged.realigned.mateFixed.bam" \
        OUTPUT="${patientID}.merged.realigned.rmDups.bam" \
        METRICS_FILE="${patientID}.merged.realigned.mateFixed.metrics" \
        REMOVE_DUPLICATES=TRUE \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT || error "Mark duplicates failed"

rm -f "${patientID}.merged.realigned.mateFixed.bam"

echo "[Recal] Index BAM file..."
$SAMTOOLS index "${patientID}.merged.realigned.rmDups.bam" || error "Second indexing failed"

echo "[Recal] Base-quality recalibration: Count covariates..."
$JAVA -Xmx4g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
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
        --recal_file "${patientID}.merged.realigned.rmDups.csv" || error "First CountCovariates failed"

echo "[Recal] Base-quality recalibration: Table Recalibration..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type TableRecalibration \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --baq RECALCULATE \
        --recal_file "${patientID}.merged.realigned.rmDups.csv" \
        --input_file "${patientID}.merged.realigned.rmDups.bam" \
        --out "${patientID}.merged.realigned.rmDups.recal.bam" || error "TableRecalibration failed"

rm -f "${patientID}.merged.realigned.rmDups.bam"
rm -f "${patientID}.merged.realigned.rmDups.bam.bai"
rm -f "${patientID}.merged.realigned.rmDups.csv"

echo "[Recal] Index BAM file..."
$SAMTOOLS index "${patientID}.merged.realigned.rmDups.recal.bam" || error "Third indexing failed"

echo "[Recal] Split BAM files..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type SplitSamFile \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --input_file "${patientID}.merged.realigned.rmDups.recal.bam" \
        --outputRoot temp_ || error "Splitting BAM files failed"

rm -f "${patientID}.merged.realigned.rmDups.recal.bam"
rm -f "${patientID}.merged.realigned.rmDups.recal.bam.bai"
rm -f "${patientID}.merged.realigned.rmDups.recal.bai"

for i in temp_*.bam
do
        base=${i##temp_}
        base=${base%%.bam}
        echo "[Recal] Splitting off $base..."
        $SAMTOOLS sort "$i" "${base}.bwa.realigned.rmDups.recal" || error "Sorting $base failed"
        $SAMTOOLS index "${base}.bwa.realigned.rmDups.recal.bam" || error "Indexing $base failed"
        rm -f "$i"
done

echo "[Recal] Finished!"
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
        $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CalculateHsMetrics.jar" \
                BAIT_INTERVALS="${ilist}" \
                TARGET_INTERVALS="${ilist}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || error "Calculate hybrid selection metrics failed"

        echo "[QC] Collect multiple QC metrics..."
        $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CollectMultipleMetrics.jar" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || error "Collect multiple QC metrics failed"
        echo "------------------------------------------------------"
done

echo "[QC] Finished!"
echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
