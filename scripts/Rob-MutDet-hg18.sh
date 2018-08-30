#!/bin/bash
#
## Mutation detection with muTect, and Unified Genotyper
##
## Exmaple run: path/to/MutDet.sh path/to/Normal.bam path/to/Tumor.bam output_prefix patientID
#
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#

nbamfile=$1
tbamfile=$2
prefix=$3
patientID=$4
section=$5

normalname=${nbamfile##*/}
normalname=${normalname%%.bwa*}
tumorname=${tbamfile##*/}
tumorname=${tumorname%%.bwa*}

JAVA=/home/jocostello/shared/LG3_Pipeline/tools/java/jre1.6.0_27/bin/java
PYTHON=/usr/bin/python
TMP="/scratch"
GATK="/home/jocostello/shared/LG3_Pipeline/tools/GenomeAnalysisTK-1.6-5-g557da77/GenomeAnalysisTK.jar"
MUTECT="/home/jocostello/shared/LG3_Pipeline/tools/muTect-1.0.27783.jar"
#ILIST="/home/jocostello/shared/LG3_Pipeline/resources/029720_D_BED_20101013_agilent_50mb_exon_hg19.interval_list"
#REF="/home/jocostello/shared/LG3_Pipeline/resources/UCSC_HG19_Feb_2009/hg19.fa"
REF="/home/bellr/data/ReferenceGenomes/Homo_sapiens_assembly18.fasta"
#DBSNP="/home/jocostello/shared/LG3_Pipeline/resources/dbsnp_132.hg19.sorted.vcf"
FILTER=/home/jocostello/shared/LG3_Pipeline/FilterMutations/Filter.py
CONFIG="/home/bellr/scripts/TCGA.WGS.mutationConfig-MutectCOVERED.cfg"
INDELS="/home/bellr/scripts/IndelPlaceHolder.indels"

echo "-------------------------------------------------"
echo "[MutDet] Mutation detection"
echo "-------------------------------------------------"
echo "[MutDet] Patient ID: $patientID"
echo "[MutDet] Normal Sample: $normalname"
echo "[MutDet] Tumor Sample: $tumorname"
echo "-------------------------------------------------"
echo "[MutDet] Normal bam file: $nbamfile"
echo "[MutDet] Tumor bam file: $tbamfile"
echo "-------------------------------------------------"

if [ ! -e "${prefix}.snvs.raw.mutect.txt" ]; then
	echo "[MutDet] Running muTect..."
	$JAVA -Xmx2g -Djava.io.tmpdir=${TMP} \
		-jar $MUTECT \
		--analysis_type MuTect \
		--logging_level WARN \
		--reference_sequence $REF \
		--input_file:normal "$nbamfile" \
		--input_file:tumor "$tbamfile" \
		-baq CALCULATE_AS_NECESSARY \
		-L "$section" \
		-nt 2 \
		--out "${prefix}.snvs.raw.mutect.txt" \
		--coverage_file "${prefix}.snvs.coverage.mutect.wig" || { echo "muTect failed"; exit 1; }
fi

if [ ! -e "${prefix}.mutations" ]; then
	echo "[MutDet] Filtering mutect and indel output..."
	source /home/jocostello/shared/LG3_Pipeline/FilterMutations/filter.profile.sh
	$FILTER \
		$CONFIG \
		"${prefix}.snvs.raw.mutect.txt" \
		$INDELS \
		"${prefix}.mutations" || { echo "Filtering failed"; exit 1; }
fi

echo "[MutDet] Finished!"

if [ ! -e "${patientID}.${prefix}.annotated.mutations" ]; then
	echo "-------------------------------------------------"
	echo "[Annotate] Annotation of mutations"
	echo "-------------------------------------------------"
	echo "[Annotate] Annotating file: ${prefix}.mutations"
	echo "[Annotate] Output file: ${patientID}.${prefix}.annotated.mutations"
	echo "-------------------------------------------------"

	echo "[Annotate] Generate bed file from mutations..."
	$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/annotation_BED_forUG.py \
		"${prefix}.mutations" \
		> "${patientID}.${prefix}.temp.bed" || { echo "Bed file creation failed"; exit 1; }

	echo "[Annotate] Generate Unified Genotyper data..."
	$JAVA -Xmx2g \
		-jar $GATK \
		--analysis_type UnifiedGenotyper \
		--genotype_likelihoods_model SNP \
		--genotyping_mode DISCOVERY \
		--input_file "$nbamfile" \
		--input_file "$tbamfile" \
		--reference_sequence "$REF" \
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

	echo "[Annotate] Annotating Unified Genotyper SNPs..."
	$JAVA -Xmx2g \
		-jar $GATK \
		--analysis_type VariantAnnotator \
		--input_file "$nbamfile" \
		--input_file "$tbamfile" \
		--reference_sequence "$REF" \
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
--annotation HomopolymerRun \
		--out "${patientID}.${prefix}.UG.snps.annotated.vcf" || { echo "Unified Genotyper SNP annotation failed"; exit 1; }

	rm -f "${patientID}.${prefix}.UG.snps.raw.vcf"
	rm -f "${patientID}.${prefix}.UG.snps.raw.vcf.idx"

	echo "[Annotate] Filtering Unified Genotyper SNPs..."
	$JAVA -Xmx2g \
		-jar $GATK \
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
		--filterName ReadPosFilter	\
--filterExpression "HRun > 4" \
--filterName HomopolymerRun \
		--out "${patientID}.${prefix}.UG.snps.filtered.vcf" || { echo "Unified Genotyper SNP filtration failed"; exit 1; }

	rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf"
	rm -f "${patientID}.${prefix}.UG.snps.annotated.vcf.idx"

	echo "[Annotate] Add Unified Genotyper data..."
	$PYTHON /home/jocostello/shared/LG3_Pipeline/scripts/annotation_UG.py \
		"${prefix}.mutations" \
		"${patientID}.${prefix}.UG.snps.filtered.vcf" \
		> "${patientID}.${prefix}.UG.Annotated.mutations" || { echo "Unified Genotyper annotation failed"; exit 1; }

	rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf"
	rm -f "${patientID}.${prefix}.UG.snps.filtered.vcf.idx"

	echo "[Annotate] Finished!"
fi

test1="$(echo "$section" | cut -d ':' -f1)"
if [ "$test1" == "chr22" ]; then
    echo "Creating Coverage Statistics for Chr22"
    #call GATK get coverage stats....
    echo "------------------------------------------------------"
    echo "[BAM QC] Determining Coverage Stats"
    echo "------------------------------------------------------"

    echo "[GATK] Running Depth of Coverage Walker..."
$JAVA -Xmx2g -jar $GATK \
	-T DepthOfCoverage \
	-R "$REF" \
	-I "$tbamfile" \
	-o "${prefix}.coverage" \
-L 22 \
-ct 2 -ct 8 -ct 14 || { echo "Interval creation failed"; exit 1; }

echo "[BAM QC] Removing the temp.coverage file"
rm -f "${prefix}.coverage"
fi

echo "-------------------------------------------------"
