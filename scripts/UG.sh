#!/bin/bash

### Configuration
LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
PROJECT=${PROJECT:?}
LG3_SCRATCH_ROOT=${LG3_SCRATCH_ROOT:-/scratch/${USER:?}/${PBS_JOBID}}
LG3_DEBUG=${LG3_DEBUG:-true}

### Debug
if [[ $LG3_DEBUG ]]; then
  echo "LG3_HOME=$LG3_HOME"
  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"
  echo "LG3_SCRATCH_ROOT=$LG3_SCRATCH_ROOT"
  echo "PWD=$PWD"
  echo "USER=$USER"
fi


#
PROG=$(basename "$0")
JAVA=${LG3_HOME}/tools/java/jre1.6.0_27/bin/java
PYTHON=/usr/bin/python
GATK=${LG3_HOME}/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar
REF=${LG3_HOME}/resources/UCSC_HG19_Feb_2009/hg19.fa
DBSNP=${LG3_HOME}/resources/dbsnp_132.hg19.sorted.vcf

#
help()
{
cat << EOF
This script runs GATK UnifiedGenotyper on bunch of BAM files
Usage: $0 options
OPTIONS:
   -h      this usage instructions
   -bams=  input bam file names, colon (:) separated!
   -out=   prefix for output VCF file
   -list=  interval list

BUILDIN:
        JAVA=$JAVA
        PYTHON=$PYTHON
        GATK=$GATK
        DBSNP=$DBSNP
EOF
exit 1
}
if [ $# -eq 0 ]; then
        help
        exit 1
fi

#### Parse args
while [ -n "$1" ]; do
case $1 in
   -h) help "$0";shift 1;;
   -b*=*) BAMS=${1#*=};shift 1;;
   -o*=*) OUT=${1#*=};shift 1;;
   -l*=*) LIST=${1#*=};shift 1;;
   -*) echo "[$PROG] ERROR: no such option $1. Try -h for help";exit 1;;
   *)  break;;
esac
done

if [[ -z $BAMS ]] || [[ -z $OUT ]] || [[ -z $LIST ]]; then
          echo "[$PROG] ERROR: some args are not set!" 
     exit 1
fi

if [ -e "${OUT}.UG.snps.vcf" ]; then
        echo "[$PORG] ERROR: Output file exists: ${OUT}.UG.snps.vcf"
        exit 1
fi

echo "-------------------------------------------------"
echo "[$PROG] OPTIONS set:"
echo "-------------------------------------------------"
echo "[$PROG] Input BAM files : $BAMS"
echo "[$PROG] Output VCF prefix : $OUT"
echo "[$PROG] Target interval list : $LIST"
echo "-------------------------------------------------"

## Construct string with one or more '-I <bam>' elements
INPUTS=$(echo "$BAMS" | awk -F ":" '{OFS=" "} {for (i=1; i<=NF; i++) printf "-I "$i" "}')
echo "[$PROG] Inputs = $INPUTS"

        echo "[$PROG] Running Unified Genotyper SNP calling ..."
        # shellcheck disable=SC2086
        # Comment: Because how INPUTS is created and used below
        $JAVA -Xmx8g \
                -jar "$GATK" \
                --analysis_type UnifiedGenotyper \
                -nct 3 -nt 8 \
                --genotype_likelihoods_model SNP \
                --genotyping_mode DISCOVERY \
                $INPUTS \
                --reference_sequence "$REF" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "$LIST" \
                -baq CALCULATE_AS_NECESSARY \
                --noSLOD \
                --standard_min_confidence_threshold_for_calling 30.0 \
                --standard_min_confidence_threshold_for_emitting 10.0 \
                --min_base_quality_score 20 \
                --output_mode EMIT_VARIANTS_ONLY \
                --out "${OUT}.UG.snps.raw.vcf" || { echo "FAILED!"; exit 1; }

        echo "[$PROG] Annotating Unified Genotyper SNPs..."
        $JAVA -Xmx8g \
                -jar "$GATK" \
                --analysis_type VariantAnnotator \
                "$INPUTS" \
                --reference_sequence "{$REF}" \
                --dbsnp "$DBSNP" \
                --logging_level WARN \
                --intervals "${OUT}.UG.snps.raw.vcf" \
                --variant "${OUT}.UG.snps.raw.vcf" \
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
                --out "${OUT}.UG.snps.annotated.vcf" || { echo "Unified Genotyper SNP annotation failed"; exit 1; }

        rm -f "${OUT}.UG.snps.raw.vcf"
        rm -f "${OUT}.UG.snps.raw.vcf.idx"

        echo "[$PROG] Filtering Unified Genotyper SNPs..."
        $JAVA -Xmx8g \
                -jar "$GATK" \
                --analysis_type VariantFiltration \
                --reference_sequence "$REF" \
                --logging_level WARN \
                --variant "${OUT}.UG.snps.annotated.vcf" \
                -baq CALCULATE_AS_NECESSARY \
                --clusterSize 3 \
                --clusterWindowSize 10 \
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
                --out "${OUT}.UG.snps.vcf" || { echo "FAILED!"; exit 1; }

        rm -f "${OUT}.UG.snps.annotated.vcf"
        rm -f "${OUT}.UG.snps.annotated.vcf.idx"

echo "[$PROG] Finished!"
echo "-------------------------------------------------"
