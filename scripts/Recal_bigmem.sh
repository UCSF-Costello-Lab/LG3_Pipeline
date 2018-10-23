#!/bin/bash

PROGRAM=${BASH_SOURCE[0]}
PROG=$(basename "$PROGRAM")
echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] BEGIN: $PROGRAM"
echo "Call: ${BASH_SOURCE[*]}"
echo "Script: $PROGRAM"
echo "Arguments: $*"

### Configuration
LG3_HOME=${LG3_HOME:?}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-output}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}
ncores=${PBS_NUM_PPN:-1}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "$PROG Settings:"
  echo "- LG3_HOME=$LG3_HOME"
  echo "- LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "- LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "- PWD=$PWD"
  echo "- USER=$USER"
  echo "- PBS_NUM_PPN=$PBS_NUM_PPN"
  echo "- hostname=$(hostname)"
  echo "- ncores=$ncores"
fi


#
## Base quality recalibration, prep for indel detection, and quality control
#
## Usage: /path/to/Recal.sh <bamfiles> <PATIENT> <exome_kit.interval_list>
#
#

## References
REF=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa
THOUSAND=${LG3_HOME}/resources/1000G_biallelic.indels.hg19.sorted.vcf
DBSNP=${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf
echo "References:"
echo "- REF=${REF:?}"
echo "- THOUSAND=${THOUSAND:?}"
echo "- DBSNP=${DBSNP:?}"
[[ -f "$REF" ]]      || { echo "File not found: ${REF}"; exit 1; }
[[ -f "$THOUSAND" ]] || { echo "File not found: ${THOUSAND}"; exit 1; }
[[ -f "$DBSNP" ]]    || { echo "File not found: ${DBSNP}"; exit 1; }

## Software
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
SAMTOOLS=${LG3_HOME}/tools/samtools-0.1.18/samtools
GATK="${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
PICARD_HOME=${LG3_HOME}/tools/picard-tools-1.64
PICARD_SCRIPT_A=${PICARD_HOME}/MergeSamFiles.jar
PICARD_SCRIPT_B=${PICARD_HOME}/FixMateInformation.jar
PICARD_SCRIPT_C=${PICARD_HOME}/MarkDuplicates.jar
PICARD_SCRIPT_D=${PICARD_HOME}/CalculateHsMetrics.jar
PICARD_SCRIPT_E=${PICARD_HOME}/CollectMultipleMetrics.jar

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- SAMTOOLS=${SAMTOOLS:?}"
echo "- GATK=${GATK:?}"
echo "- PICARD_HOME=${PICARD_HOME:?}"

## Assert existance of software
[[ -x "$JAVA" ]]            || { echo "Not an executable: ${JAVA}"; exit 1; }
[[ -x "$SAMTOOLS" ]]        || { echo "Not an executable: ${SAMTOOLS}"; exit 1; }
[[ -f "$GATK" ]]            || { echo "File not found: ${GATK}"; exit 1; }
[[ -d "$PICARD_HOME" ]]     || { echo "File not found: ${PICARD_HOME}"; exit 1; }
[[ -f "$PICARD_SCRIPT_A" ]] || { echo "File not found: ${PICARD_SCRIPT_A}"; exit 1; }
[[ -f "$PICARD_SCRIPT_B" ]] || { echo "File not found: ${PICARD_SCRIPT_B}"; exit 1; }
[[ -f "$PICARD_SCRIPT_C" ]] || { echo "File not found: ${PICARD_SCRIPT_C}"; exit 1; }
[[ -f "$PICARD_SCRIPT_D" ]] || { echo "File not found: ${PICARD_SCRIPT_D}"; exit 1; }
[[ -f "$PICARD_SCRIPT_E" ]] || { echo "File not found: ${PICARD_SCRIPT_E}"; exit 1; }


## Input
bamfiles=$1
PATIENT=$2
ILIST=$3
echo "Input:"
echo "- bamfiles=${bamfiles:?}"
echo "- PATIENT=${PATIENT:?}"
echo "- ILIST=${ILIST:?}"

## Assert existance of input files
[[ -f "$ILIST" ]] || { echo "File not found: ${ILIST}"; exit 1; }


TMP="${LG3_SCRATCH_ROOT}/${PATIENT}_tmp"
mkdir -p "${TMP}" || { echo "Can't create scratch directory ${TMP}"; exit 1; }

echo "------------------------------------------------------"
echo "[Recal] Base quality recalibration (bigmem version)"
date
echo "------------------------------------------------------"
echo "[Recal] Recalibration Group: $PATIENT"
echo "$bamfiles" | awk -F ":" '{for (i=1; i<=NF; i++) print "[Recal] Exome:"$i}'
echo "------------------------------------------------------"

## Construct string with one or more '-I "<bam>"' elements
inputs=$(echo "$bamfiles" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "INPUT=\""$i"\" "}')

echo -e "\\n[Recal] Merge BAM files..."
# shellcheck disable=SC2086

# Comment: Because how 'inputs' is created and used below
{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_A}" \
        ${inputs} \
        OUTPUT="${PATIENT}.merged.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || { echo "Merge BAM files failed"; exit 1; }

echo -e "\\n[Recal] Index new BAM file..."
{ time $SAMTOOLS index "${PATIENT}.merged.bam"; } 2>&1 || { echo "First indexing failed"; exit 1; }

echo -e "\\n[Recal] Create intervals for indel detection..."
{ time $JAVA -Xmx8g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type RealignerTargetCreator \
        --reference_sequence "$REF" \
        --known "$THOUSAND" \
		  -L "${ILIST}" \
        --num_threads "${ncores}" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.bam" \
        --out "${PATIENT}.merged.intervals"; } 2>&1 || { echo "Interval creation failed"; exit 1; }

echo -e "\\n[Recal] Indel realignment..."
{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "$GATK" \
        --analysis_type IndelRealigner \
        --reference_sequence "$REF" \
        --knownAlleles "$THOUSAND" \
        --logging_level WARN \
        --consensusDeterminationModel USE_READS \
        --input_file "${PATIENT}.merged.bam" \
        --targetIntervals "${PATIENT}.merged.intervals" \
        --out "${PATIENT}.merged.realigned.bam"; } 2>&1 || { echo "Indel realignment failed"; exit 1; }

rm -f "${PATIENT}.merged.bam"
rm -f "${PATIENT}.merged.bam.bai"
rm -f "${PATIENT}.merged.intervals"

echo -e "\\n[Recal] Fix mate information..."
{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_B}" \
        INPUT="${PATIENT}.merged.realigned.bam" \
        OUTPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        SORT_ORDER=coordinate \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=SILENT; } 2>&1 || { echo "Verify mate information failed"; exit 1; } 

rm -f "${PATIENT}.merged.realigned.bam"
rm -f "${PATIENT}.merged.realigned.bai"

echo -e "\\n[Recal] Mark duplicates..."
{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
        -jar "${PICARD_SCRIPT_C}" \
        INPUT="${PATIENT}.merged.realigned.mateFixed.bam" \
        OUTPUT="${PATIENT}.merged.realigned.rmDups.bam" \
        METRICS_FILE="${PATIENT}.merged.realigned.mateFixed.metrics" \
        REMOVE_DUPLICATES=TRUE \
        TMP_DIR="${TMP}" \
        VERBOSITY=WARNING \
        QUIET=true \
        VALIDATION_STRINGENCY=LENIENT; } 2>&1 || { echo "Mark duplicates failed"; exit 1; }

rm -f "${PATIENT}.merged.realigned.mateFixed.bam"

echo -e "\\n[Recal] Index BAM file..."
{ time $SAMTOOLS index "${PATIENT}.merged.realigned.rmDups.bam"; } 2>&1 || { echo "Second indexing failed"; exit 1; } 

### Job crushed at -Xmx8g, increase!
echo -e "\\n[Recal] Base-quality recalibration: Count covariates..."
{ time $JAVA -Xmx128g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
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
        --input_file "${PATIENT}.merged.realigned.rmDups.bam" \
        --recal_file "${PATIENT}.merged.realigned.rmDups.csv"; } 2>&1 || { echo "CountCovariates failed"; exit 1; }

echo -e "\\n[Recal] Base-quality recalibration: Table Recalibration..."
{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type TableRecalibration \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --baq RECALCULATE \
        --recal_file "${PATIENT}.merged.realigned.rmDups.csv" \
        --input_file "${PATIENT}.merged.realigned.rmDups.bam" \
        --out "${PATIENT}.merged.realigned.rmDups.recal.bam"; } 2>&1 || { echo "TableRecalibration failed"; exit 1; }

rm -f "${PATIENT}.merged.realigned.rmDups.bam"
rm -f "${PATIENT}.merged.realigned.rmDups.bam.bai"
rm -f "${PATIENT}.merged.realigned.rmDups.csv"

echo -e "\\n[Recal] Index BAM file..."
{ time $SAMTOOLS index "${PATIENT}.merged.realigned.rmDups.recal.bam"; } 2>&1 || { echo "Third indexing failed"; exit 1; } 

echo -e "\\n[Recal] Split BAM files..."
{ time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" -jar "$GATK" \
        --analysis_type SplitSamFile \
        --reference_sequence "$REF" \
        --logging_level WARN \
        --input_file "${PATIENT}.merged.realigned.rmDups.recal.bam" \
        --outputRoot temp_; } 2>&1 || { echo "Splitting BAM files failed"; exit 1; }

rm -f "${PATIENT}.merged.realigned.rmDups.recal.bam"
rm -f "${PATIENT}.merged.realigned.rmDups.recal.bam.bai"
rm -f "${PATIENT}.merged.realigned.rmDups.recal.bai"

for i in temp_*.bam
do
        base=${i##temp_}
        base=${base%%.bam}
        echo -e "\\n[Recal] Splitting off $base..."
        { time $SAMTOOLS sort "$i" "${base}.bwa.realigned.rmDups.recal"; } 2>&1 || { echo "Sorting $base failed"; exit 1; }
        { time $SAMTOOLS index "${base}.bwa.realigned.rmDups.recal.bam"; } 2>&1 || { echo "Indexing $base failed"; exit 1; }        
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

        echo -e "\\n[QC] Calculate flag statistics..."
        { time $SAMTOOLS flagstat "$i" > "${base}.bwa.realigned.rmDups.recal.flagstat"; } 2>&1

        echo -e "\\n[QC] Calculate hybrid selection metrics..."
        { time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_SCRIPT_D}" \
                BAIT_INTERVALS="${ILIST}" \
                TARGET_INTERVALS="${ILIST}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal.hybrid_selection_metrics" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || { echo "Calculate hybrid selection metrics failed"; exit 1; }

        echo -e "\\n[QC] Collect multiple QC metrics..."
        { time $JAVA -Xmx16g -Djava.io.tmpdir="${TMP}" \
                -jar "${PICARD_SCRIPT_E}" \
                INPUT="$i" \
                OUTPUT="${base}.bwa.realigned.rmDups.recal" \
                REFERENCE_SEQUENCE="${REF}" \
                TMP_DIR="${TMP}" \
                VERBOSITY=WARNING \
                QUIET=true \
                VALIDATION_STRINGENCY=SILENT; } 2>&1 || { echo "Collect multiple QC metrics failed"; exit 1; }
        echo "------------------------------------------------------"
done

echo -ne "\\n[QC] Finished! "
date
echo "-------------------------------------------------"

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
