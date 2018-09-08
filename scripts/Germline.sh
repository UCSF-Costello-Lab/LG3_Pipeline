#!/bin/bash
#
## Mutation detection with muTect, Somatic Indel Detector, and Unified Genotyper
##
## Exmaple run: path/to/Germline.sh path/to/Normal.bam path/to/Tumor.bam output_prefix patientID
#
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

nbamfile=$1
patientID=$2
ILIST=$3

normalname=${nbamfile##*/}
normalname=${normalname%%.bwa*}
bamdir=${nbamfile%/*}

JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java

PYTHON=/usr/bin/python
GATK="/home/jocostello/shared/LG3_Pipeline/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
REF="/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.fa"
DBSNP="/home/jocostello/shared/LG3_Pipeline/resources/dbsnp_132.hg19.sorted.vcf"

echo "-------------------------------------------------"
echo "[Germline] Germline SNPs and relatedness"
echo "-------------------------------------------------"
echo "[Germline] Patient ID: $patientID"
echo "[Germline] Bam file directory: $bamdir"
echo "[Germline] Normal Sample: $normalname"
echo "-------------------------------------------------"

## Construct string with one or more '-I <bam>' elements
INPUTS=$(for i in ${bamdir}/*.bam
do
	echo -n "-I $i "
done)
echo "$INPUTS"

	### $JAVA -Xmx16g \
	### -nct 3 -nt 8 \
if [ ! -e "${patientID}.UG.snps.raw.vcf" ]; then
	echo "[Germline] Running Unified Genotyper..."
	# shellcheck disable=SC2086
	# Comment: Because how INPUTS is created and used below
	$JAVA -Xmx64g \
		-jar $GATK \
		--analysis_type UnifiedGenotyper \
		--genotype_likelihoods_model SNP \
		--genotyping_mode DISCOVERY \
	        $INPUTS \
		--reference_sequence $REF \
		--dbsnp $DBSNP \
		--logging_level WARN \
		--intervals "$ILIST" \
		-baq CALCULATE_AS_NECESSARY \
		--noSLOD \
		-nt 8 \
		--standard_min_confidence_threshold_for_calling 30.0 \
		--standard_min_confidence_threshold_for_emitting 10.0 \
		--min_base_quality_score 20 \
		--output_mode EMIT_VARIANTS_ONLY \
		--out "${patientID}.UG.snps.raw.vcf" || { echo "Unified Genotyper SNP calling failed"; exit 1; }
else
	echo "[Germline] Found output ${patientID}.UG.snps.raw.vcf -- Skipping..."
fi

if [ ! -e "${patientID}.UG.snps.annotated.vcf" ]; then
	echo "[Germline] Annotating Unified Genotyper SNPs..."
	# shellcheck disable=SC2086
	# Comment: Because how INPUTS is created and used below
	$JAVA -Xmx64g \
		-jar $GATK \
		--analysis_type VariantAnnotator \
		$INPUTS \
		--reference_sequence $REF \
		--dbsnp $DBSNP \
		--logging_level WARN \
		--intervals "${patientID}.UG.snps.raw.vcf" \
		--variant "${patientID}.UG.snps.raw.vcf" \
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
		--out "${patientID}.UG.snps.annotated.vcf" || { echo "Unified Genotyper SNP annotation failed"; exit 1; }

	rm -f "${patientID}.UG.snps.raw.vcf"
	rm -f "${patientID}.UG.snps.raw.vcf.idx"
else
   echo "[Germline] Found output ${patientID}.UG.snps.annotated.vcf -- Skipping..."
fi

if [ ! -e "${patientID}.UG.snps.vcf" ]; then
	echo "[Germline] Filtering Unified Genotyper SNPs..."
	$JAVA -Xmx64g \
		-jar $GATK \
		--analysis_type VariantFiltration \
		--reference_sequence $REF \
		--logging_level WARN \
		--variant "${patientID}.UG.snps.annotated.vcf" \
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
		--filterName ReadPosFilter	\
		--out "${patientID}.UG.snps.vcf" || { echo "Unified Genotyper SNP filtration failed"; exit 1; }

	rm -f "${patientID}.UG.snps.annotated.vcf"
	rm -f "${patientID}.UG.snps.annotated.vcf.idx"
else
   echo "[Germline] Found output ${patientID}.UG.snps.vcf -- Skipping..."
fi

for i in ${bamdir}/*.bam
do
	tumorname=${i##*/}
	tumorname=${tumorname%%.bwa*}
	prefix="NOR-${normalname}_vs_${tumorname}"

	if [ ! -e "${prefix}.germline" ]; then
		echo "[Germline] Checking germline SNPs for sample relatedness: $tumorname vs $normalname"
		$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/vcf_germline.py \
			"${patientID}.UG.snps.vcf" \
			"$normalname" \
			"$tumorname" \
			> "${prefix}.germline" || { echo "Germline analysis failed"; exit 1; }
	else
		echo "[Germline] ${prefix}.germline already exists, skipping analysis"
	fi
done

if [ -e "NOR-${normalname}_vs_${normalname}.germline" ]; then
	echo "[Germline] Deleting germline vs. germline comparison..."
	rm -f "NOR-${normalname}_vs_${normalname}.germline"
fi

echo "[Germline] Finished!"
echo "-------------------------------------------------"
