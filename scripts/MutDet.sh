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
## Mutation detection with muTect, Somatic Indel Detector, and Unified Genotyper
##
## Exmaple run: path/to/MutDet.sh path/to/Normal.bam path/to/Tumor.bam output_prefix patientID
#
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#


### Input
nbamfile=$1
tbamfile=$2
prefix=$3
patientID=$4
CONFIG=$5
ILIST=$6
XMX=$7 ### Xmx8g

echo "Input:"
echo "- nbamfile=${nbamfile:?}"
echo "- tbamfile=${tbamfile:?}"
echo "- prefix=${prefix:?}"
echo "- patientID=${patientID:?}"
echo "- CONFIG=${CONFIG:?}"
echo "- ILIST=${ILIST:?}"
echo "- XMX=${XMX:?}"

## Assert existance of input files
[[ -f "$nbamfile" ]] || { echo "File not found: ${nbamfile}"; exit 1; }
[[ -f "$tbamfile" ]] || { echo "File not found: ${tbamfile}"; exit 1; }
[[ -f "$CONFIG" ]] || { echo "File not found: ${CONFIG}"; exit 1; }
[[ -f "$ILIST" ]] || { echo "File not found: ${ILIST}"; exit 1; }

normalname=${nbamfile##*/}
normalname=${normalname%%.bwa*}
tumorname=${tbamfile##*/}
tumorname=${tumorname%%.bwa*}

### Software
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PYTHON=/usr/bin/python
GATK="${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
MUTECT="${LG3_HOME}/tools/muTect-1.0.27783.jar"
FILTER=${LG3_HOME}/FilterMutations/Filter.py
REORDER="${LG3_HOME}/scripts/vcf_reorder.py"

echo "Software:"
echo "- JAVA=${JAVA:?}"
echo "- PYTHON=${PYTHON:?}"
echo "- MUTECT=${MUTECT:?}"
echo "- FILTER=${FILTER:?}"
echo "- REORDER=${REORDER:?}"

## Assert existance of software
[[ -x "$JAVA" ]]   || { echo "Not an executable: ${JAVA}"; exit 1; }
[[ -x "$PYTHON" ]] || { echo "Not an executable: ${PYTHON}"; exit 1; }
[[ -f "$GATK" ]]   || { echo "File not found: ${GATK}"; exit 1; }
[[ -f "$MUTECT" ]] || { echo "File not found: ${MUTECT}"; exit 1; }
[[ -f "$FILTER" ]] || { echo "File not found: ${FILTER}"; exit 1; }
[[ -f "$REORDER" ]] || { echo "File not found: ${REORDER}"; exit 1; }

### References
REF="${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa"
DBSNP="${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf"
CONVERT="${LG3_HOME}/resources/RefSeq.Entrez.txt"
KINASEDATA="${LG3_HOME}/resources/all_human_kinases.txt"
COSMICDATA="${LG3_HOME}/resources/CosmicMutantExport_v58_150312.tsv"
CANCERDATA="${LG3_HOME}/resources/SangerCancerGeneCensus_2012-03-15.txt"

echo "References:"
echo "- REF=${REF}"
echo "- DBSNP=${DBSNP}"
echo "- REORDER=${REORDER}"
echo "- CONVERT=${CONVERT}"
echo "- KINASEDATA=${KINASEDATA}"
echo "- COSMICDATA=${COSMICDATA}"
echo "- CANCERDATA=${CANCERDATA}"

## Assert existance of files
[[ -f "${REF}" ]]        || { echo "File not found: ${REF}"; exit 1; }
[[ -f "${DBSNP}" ]]      || { echo "File not found: ${DBSNP}"; exit 1; }
[[ -f "${REORDER}" ]]    || { echo "File not found: ${REORDER}"; exit 1; }
[[ -f "${CONVERT}" ]]    || { echo "File not found: ${CONVERT}"; exit 1; }
[[ -f "${KINASEDATA}" ]] || { echo "File not found: ${KINASEDATA}"; exit 1; }
[[ -f "${COSMICDATA}" ]] || { echo "File not found: ${COSMICDATA}"; exit 1; }
[[ -f "${CANCERDATA}" ]] || { echo "File not found: ${CANCERDATA}"; exit 1; }


TMP="${SCRATCHDIR}"

echo "-------------------------------------------------"
echo -n "[MutDet] Mutation detection "
date
echo "-------------------------------------------------"
echo "[MutDet] Patient ID: $patientID"
echo "[MutDet] Normal Sample: $normalname"
echo "[MutDet] Tumor Sample: $tumorname"
echo "[MutDet] Prefix: $prefix"
echo "-------------------------------------------------"
echo "[MutDet] Normal bam file: $nbamfile"
echo "[MutDet] Tumor bam file: $tbamfile"
echo "[MutDet] Java Memory Xmx value: $XMX"
echo -n "[MutDet] Working directory: "
pwd
echo "-------------------------------------------------"

if [ ! -e "${prefix}.snvs.raw.mutect.txt" ]; then
        echo "[MutDet] Running muTect..."
        $JAVA -"$XMX" -Djava.io.tmpdir="${TMP}" \
                -jar "$MUTECT" \
                --analysis_type MuTect \
                --logging_level WARN \
                --reference_sequence "$REF" \
                --intervals "$ILIST" \
                --input_file:normal "$nbamfile" \
                --input_file:tumor "$tbamfile" \
                -baq CALCULATE_AS_NECESSARY \
                --out "${prefix}.snvs.raw.mutect.txt" \
                --coverage_file "${prefix}.snvs.coverage.mutect.wig" || { echo "muTect failed"; exit 1; }
                echo "Done"
else
        echo "[MutDet] Found MuTect output, skipping ..."
fi
wc -l "${prefix}.snvs.raw.mutect.txt"

if [ ! -e "${prefix}.indels.raw.vcf" ]; then
        echo "[MutDet] Running Somatic Indel Detector..."
                ##--window_size 225 \
        $JAVA "-$XMX" -Djava.io.tmpdir="${TMP}" \
                -jar "$GATK" \
                --analysis_type SomaticIndelDetector \
                -I:normal "$nbamfile" \
                -I:tumor "$tbamfile" \
                --logging_level INFO \
                --reference_sequence "$REF" \
                --intervals "$ILIST" \
                -baq CALCULATE_AS_NECESSARY \
                --maxNumberOfReads 10000 \
                --window_size 350 \
                --filter_expressions "N_COV<8||T_COV<14||T_INDEL_F<0.1||T_INDEL_CF<0.7" \
                --out "${prefix}.indels.raw.vcf" || { echo "Indel detection failed"; exit 1; }
                echo "Done"
else
        echo "[MutDet] Found Somatic Indel Detector output, skipping ..."
fi
wc -l "${prefix}.indels.raw.vcf"

if [ ! -e "${prefix}.indels.annotated.vcf" ]; then
        echo "[MutDet] Annotating raw indel calls..."
        $JAVA "-$XMX" -Djava.io.tmpdir="${TMP}" \
                -jar "$GATK" \
                --analysis_type VariantAnnotator \
                --variant "${prefix}.indels.raw.vcf" \
                --intervals "${prefix}.indels.raw.vcf" \
                -I:normal "$nbamfile" \
                -I:tumor "$tbamfile" \
                --logging_level WARN \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --group StandardAnnotation \
                --out "${prefix}.indels.annotated.vcf" || { echo "Indel annotation failed"; exit 1; }
                echo "Done"
else
        echo "[MutDet] Found InDel Annotation output, skipping ..."
fi
wc -l "${prefix}.indels.annotated.vcf"

if [ ! -e "${prefix}.mutations" ]; then
        echo "[MutDet] Reordering indel vcf..."
        $PYTHON "$REORDER" "${prefix}.indels.annotated.vcf" \
                "$tumorname" \
                "$normalname" \
                > "${prefix}.indels.annotated.temp.vcf" || { echo "Reordering failed"; exit 1; }
        echo "Done"
        wc -l "${prefix}.indels.annotated.temp.vcf"

        echo "[MutDet] Filtering mutect and indel output..."
        # shellcheck source=FilterMutations/filter.profile.sh
        source "${LG3_HOME}/FilterMutations/filter.profile.sh"
        $FILTER \
                "$CONFIG" \
                "${prefix}.snvs.raw.mutect.txt" \
                "${prefix}.indels.annotated.temp.vcf" \
                "${prefix}.mutations" || { echo "Filtering failed"; exit 1; }
        echo "Done"

        rm -f "${prefix}.indels.annotated.temp.vcf"
else
        echo "[MutDet] Found Filtered Mutation output, skipping ..."
fi

echo "[MutDet] Finished!"
wc -l "${prefix}.mutations"

if [ ! -e "${patientID}.${prefix}.annotated.mutations" ]; then
        echo "-------------------------------------------------"
        echo "[Annotate] Annotation of mutations"
        echo "-------------------------------------------------"
        echo "[Annotate] Annotating file: ${prefix}.mutations"
        echo "[Annotate] Output file: ${patientID}.${prefix}.annotated.mutations"
        echo "-------------------------------------------------"

        echo "[Annotate] Generate bed file from mutations..."
        $PYTHON "${LG3_HOME}/scripts/annotation_BED_forUG.py" \
                "${prefix}.mutations" \
                > "${patientID}.${prefix}.temp.bed" || { echo "Bed file creation failed"; exit 1; }
        wc -l "${patientID}.${prefix}.temp.bed"

        echo "[Annotate] Generate Unified Genotyper data..."
        $JAVA "-$XMX" \
                -jar "$GATK" \
                --analysis_type UnifiedGenotyper \
                --genotype_likelihoods_model SNP \
                --genotyping_mode DISCOVERY \
                --input_file "$nbamfile" \
                --input_file "$tbamfile" \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "${patientID}.${prefix}.temp.bed" \
                -baq CALCULATE_AS_NECESSARY \
                --noSLOD \
                --standard_min_confidence_threshold_for_calling 30.0 \
                --standard_min_confidence_threshold_for_emitting 10.0 \
                --min_base_quality_score 20 \
                --output_mode EMIT_VARIANTS_ONLY \
                --out "${patientID}.${prefix}.UG.snps.raw.vcf" || { echo "Unified Genotyper SNP calling failed"; exit 1; }

        rm -f "${patientID}.${prefix}.temp.bed"
        wc -l "${patientID}.${prefix}.UG.snps.raw.vcf"

        echo "[Annotate] Annotating Unified Genotyper SNPs..."
        $JAVA "-$XMX" \
                -jar "$GATK" \
                --analysis_type VariantAnnotator \
                --input_file "$nbamfile" \
                --input_file "$tbamfile" \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "${patientID}.${prefix}.UG.snps.raw.vcf" \
                --variant "${patientID}.${prefix}.UG.snps.raw.vcf" \
                -baq CALCULATE_AS_NECESSARY \
                --annotation QualByDepth \
                --annotation RMSMappingQuality \
                --annotation MappingQualityZero \
                --annotation LowMQ \
                --annotation MappingQualityRankSumTest \
                --annotation FisherStrand \
                --annotation HaplotypeScore \
                --annotation ReadPosRankSumTest \
                --annotation DepthOfCoverage \
                --out "${patientID}.${prefix}.UG.snps.annotated.vcf" || { echo "Unified Genotyper SNP annotation failed"; exit 1; }

        rm -f "${patientID}.${prefix}.UG.snps.raw.vcf"
        rm -f "${patientID}.${prefix}.UG.snps.raw.vcf.idx"
        wc -l "${patientID}.${prefix}.UG.snps.annotated.vcf"

        echo "[Annotate] Filtering Unified Genotyper SNPs..."
        $JAVA "-$XMX" \
                -jar "$GATK" \
                --analysis_type VariantFiltration \
                --reference_sequence "$REF" \
                --logging_level WARN \
                --variant "${patientID}.${prefix}.UG.snps.annotated.vcf" \
                -baq CALCULATE_AS_NECESSARY \
                --filterExpression "QD < 2.0" \
                --filterName QDFilter \
                --filterExpression "MQ < 40.0" \
                --filterName MQFilter \
                --filterExpression "FS > 60.0" \
                --filterName FSFilter \
                --filterExpression "HaplotypeScore > 13.0" \
                --filterName HaplotypeScoreFilter \
                --filterExpression "MQRankSum < -12.5" \
                --filterName MQRankSumFilter \
                --filterExpression "ReadPosRankSum < -8.0" \
                --filterName ReadPosFilter        \
                --out "${patientID}.${prefix}.UG.snps.filtered.vcf" || { echo "Unified Genotyper SNP filtration failed"; exit 1; }

        rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf"
        rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf.idx"
        wc -l "${patientID}.${prefix}.UG.snps.filtered.vcf"

        echo "[Annotate] Add Unified Genotyper data..."
        $PYTHON "${LG3_HOME}/scripts/annotation_UG.py" \
                "${prefix}.mutations" \
                "${patientID}.${prefix}.UG.snps.filtered.vcf" \
                > "${patientID}.${prefix}.temp1.mutations" || { echo "Unified Genotyper annotation failed"; exit 1; }
        wc -l "${patientID}.${prefix}.temp1.mutations"

        rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf"
        rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf.idx"

        echo "[Annotate] Add COSMIC data..."
        $PYTHON "${LG3_HOME}/scripts/annotation_COSMIC.py" \
                "${patientID}.${prefix}.temp1.mutations" \
                "$COSMICDATA" \
                > "${patientID}.${prefix}.temp2.mutations" || { echo "COSMIC annotation failed"; exit 1; }
        wc -l "${patientID}.${prefix}.temp2.mutations"

        rm -f "${patientID}.${prefix}.temp1.mutations"

        echo "[Annotate] Identify kinase genes..."
        $PYTHON "${LG3_HOME}/scripts/annotation_KINASE.py" \
                "${patientID}.${prefix}.temp2.mutations" \
                "$KINASEDATA" \
                > "${patientID}.${prefix}.temp3.mutations" || { echo "Kinase gene annotation failed"; exit 1; }
        wc -l "${patientID}.${prefix}.temp3.mutations"

        rm -f "${patientID}.${prefix}.temp2.mutations"

        echo "[Annotate] Identify cancer genes..."
        $PYTHON "${LG3_HOME}/scripts/annotation_CANCER.py" \
                "${patientID}.${prefix}.temp3.mutations" \
                "$CANCERDATA" \
                "$CONVERT" \
                > "${patientID}.${prefix}.annotated.mutations" || { echo "Cancer gene annotation failed"; exit 1; }
        wc -l "${patientID}.${prefix}.annotated.mutations"

        rm -f "${patientID}.${prefix}.temp3.mutations"

        echo "[Annotate] Finished!"
else
        echo "[Annotate] Found ${patientID}.${prefix}.annotated.mutations, skipped ..."
fi

echo "-------------------------------------------------"
echo -n "All done! "
date

echo "[$(date +'%Y-%m-%d %H:%M:%S %Z')] END: $PROGRAM"
