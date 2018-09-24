#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
PROJECT=${PROJECT:?}
SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}

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
#RES="${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/resources/"
DBSNP="${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf"

#Input variables
bamfile=$1
PREF=$(basename "$bamfile" .bam)
Z=${PREF%%.*}
ilist=$2
TMP="${SCRATCHDIR}/${Z}_tmp"
mkdir -p "$TMP"
#ilist2=${LG3_HOME}/resources/SeqCap_EZ_Exome_v3_capture.interval_list

echo "------------------------------------------------------"
echo "[Recal] Base quality recalibration (WGS version)"
date
echo "------------------------------------------------------"

echo "[Recal] Create intervals for indel detection..."
$JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type RealignerTargetCreator \
        --reference_sequence "$REF" \
        --known "$THOUSAND" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --input_file "$bamfile" \
        --out "${PREF}.intervals" || { echo "Interval creation failed"; exit 1; }

echo "[Recal] Indel realignment..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type IndelRealigner \
        --reference_sequence "$REF" \
        --knownAlleles "$THOUSAND" \
        --logging_level WARN \
        --consensusDeterminationModel USE_READS \
        --input_file "$bamfile" \
        --targetIntervals "${PREF}.intervals" \
        --out "${PREF}.realigned.bam" || { echo "Indel realignment failed"; exit 1; }

rm -f "${PREF}.intervals"

echo "[Recal] Fix mate information..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/FixMateInformation.jar" \
        INPUT="${PREF}.realigned.bam" \
        OUTPUT="${PREF}.realigned.mateFixed.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT || { echo "Verify mate information failed"; exit 1; } 

rm -f "${PREF}.realigned.bam"
rm -f "${PREF}.realigned.bai"

echo "[Recal] Mark duplicates..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${LG3_HOME}/tools/picard-tools-1.64/MarkDuplicates.jar" \
        INPUT="${PREF}.realigned.mateFixed.bam" \
        OUTPUT="${PREF}.realigned.rmDups.bam" \
        METRICS_FILE="${PREF}.realigned.mateFixed.metrics" \
        REMOVE_DUPLICATES=TRUE \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT || { echo "Mark duplicates failed"; exit 1; }

rm -f "${PREF}.realigned.mateFixed.bam"

echo "[Recal] Index BAM file..."
$SAMTOOLS index "${PREF}.realigned.rmDups.bam" || { echo "Indexing failed"; exit 1; } 

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
        --input_file "${PREF}.realigned.rmDups.bam" \
        --recal_file "${PREF}.realigned.rmDups.csv" || { echo "CountCovariates failed"; exit 1; }

echo "[Recal] Base-quality recalibration: Table Recalibration..."
$JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type TableRecalibration \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --baq RECALCULATE \
        --recal_file "${PREF}.realigned.rmDups.csv" \
        --input_file "${PREF}.realigned.rmDups.bam" \
        --out "${PREF}.realigned.rmDups.recal.bam" || { echo "TableRecalibration failed"; exit 1; }

rm -f "${PREF}.realigned.rmDups.bam"
rm -f "${PREF}.realigned.rmDups.bam.bai"
rm -f "${PREF}.realigned.rmDups.csv"

echo "[Recal] Sort BAM file..."
$SAMTOOLS sort "${PREF}.realigned.rmDups.recal.bam" || { echo "Sorting failed"; exit 1; } 
echo "[Recal] Index BAM file..."
$SAMTOOLS index "${PREF}.realigned.rmDups.recal.bam" || { echo "Indexing failed"; exit 1; } 

echo "------------------------------------------------------"
echo -n "[Recal] Finished! "
date
echo "------------------------------------------------------"

echo "[QC] Quality Control"
i=${PREF}.realigned.rmDups.recal.bam


        echo "------------------------------------------------------"
        echo "[QC] $i"

        echo "[QC] Calculate flag statistics..."
        $SAMTOOLS flagstat "$i" > "${Z}.bwa.realigned.rmDups.recal.flagstat" 2>&1

        echo "[QC] Calculate hybrid selection metrics..."
        $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CalculateHsMetrics.jar" \
                BAIT_INTERVALS="${ilist}" \
                TARGET_INTERVALS="${ilist}" \
                INPUT="$i" \
                OUTPUT="${Z}.bwa.realigned.rmDups.recal.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Calculate hybrid selection metrics failed"; exit 1; }

        echo "[QC] Collect multiple QC metrics..."
        $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${LG3_HOME}/tools/picard-tools-1.64/CollectMultipleMetrics.jar" \
                INPUT="$i" \
                OUTPUT="${Z}.bwa.realigned.rmDups.recal" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT || { echo "Collect multiple QC metrics failed"; exit 1; }
        echo "------------------------------------------------------"


echo -n "[QC] $Z Finished! "
date
echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
