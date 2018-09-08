#!/bin/bash
#
##
### PINDEL
###
### /path/to/pindel_annotate.sh
##
#$ -clear
#$ -S /bin/bash
#$ -cwd
#$ -j y
#
PROG=$(basename "$0")
OK() {
        echo "OK: line $1 in $PROG"
}

datafile=$1
proj=$2
BIN=/home/jocostello/shared/LG3_Pipeline/scripts
ANNOVAR=/home/jocostello/shared/LG3_Pipeline/AnnoVar
ANNDB=/home/jocostello/shared/LG3_Pipeline/AnnoVar/hg19db/
KINASEDATA="/home/jocostello/shared/LG3_Pipeline/resources/all_human_kinases.txt"
COSMICDATA="/home/jocostello/shared/LG3_Pipeline/resources/CosmicMutantExport_v58_150312.tsv"
CANCERDATA="/home/jocostello/shared/LG3_Pipeline/resources/SangerCancerGeneCensus_2012-03-15.txt"
CONVERT="/home/jocostello/shared/LG3_Pipeline/resources/RefSeq.Entrez.txt"

echo -n "Started $PROG on "
date

### run AnnoVar
echo "================= [Annotate] run annovar"
$ANNOVAR/annotate_variation.pl -filter -dbtype 1000g2010nov_all -buildver hg19 "${datafile}.filter.intersect" $ANNDB || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO
awk -F '\t' '{for(i=3;i<=NF;i++) {printf $i"\t";} print $1}' "${datafile}.filter.intersect.hg19_ALL.sites.2010_11_dropped" > "${datafile}.tmp11"
awk -F '\t' '{for(i=1;i<=NF;i++) {printf $i"\t";} print ""}' "${datafile}.filter.intersect.hg19_ALL.sites.2010_11_filtered" > "${datafile}.tmp12"
cat "${datafile}.tmp11" "${datafile}.tmp12" > "${datafile}.tmp1"

$ANNOVAR/annotate_variation.pl -filter -dbtype 1000g2011may_all -buildver hg19 "${datafile}.tmp1" $ANNDB || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO
awk -F '\t' '{for(i=3;i<=NF;i++) {printf $i"\t";} print $1}' "${datafile}.tmp1.hg19_ALL.sites.2011_05_dropped" > "${datafile}.tmp21"
awk -F '\t' '{for(i=1;i<=NF;i++) {printf $i"\t";} print ""}' "${datafile}.tmp1.hg19_ALL.sites.2011_05_filtered" > "${datafile}.tmp22"
cat "${datafile}.tmp21" "${datafile}.tmp22" > "${datafile}.tmp2"

$ANNOVAR/annotate_variation.pl -filter -dbtype snp132 -buildver hg19 "${datafile}.tmp2" $ANNDB || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO
awk -F '\t' '{for(i=3;i<=NF;i++) {printf $i"\t";} print $1"_"$2}' "${datafile}.tmp2.hg19_snp132_dropped" > "${datafile}.tmp31"
awk -F '\t' '{for(i=1;i<=NF;i++) {printf $i"\t";} print ""}' "${datafile}.tmp2.hg19_snp132_filtered" > "${datafile}.tmp32"
cat "${datafile}.tmp31" "${datafile}.tmp32" > "${datafile}.tmp3"

$ANNOVAR/annotate_variation.pl --geneanno --buildver hg19 --outfile "${datafile}.filter.intersect.anno" "${datafile}.tmp3" $ANNDB || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO

### clean up AnnoVar exonic data, put into final mutation table format
echo "================= [Annotate] reformat annovar"
$BIN/pindel_reformat_annovar.py "${datafile}.filter.intersect.anno" "${datafile}.filter" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO

### annotate with normal coverage
echo "================= [Annotate] annotate with normal coverage"
$BIN/pindel_annotate_normal_coverage.py "${datafile}.filter.intersect.anno.muts" "${proj}" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO

## annotate with Kinase & Cosmic & Sanger Cancer Gene
echo "================= [Annotate] annotate with cosmic, kinase, sanger cancer gene list"
$BIN/annotation_COSMIC.py "${datafile}.filter.intersect.anno.muts.norm.txt" $COSMICDATA > "${datafile}.filter.intersect.anno.muts.tmp1" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO

$BIN/annotation_KINASE.py "${datafile}.filter.intersect.anno.muts.tmp1" $KINASEDATA > "${datafile}.filter.intersect.anno.muts.tmp2" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO

$BIN/annotation_CANCER.py  "${datafile}.filter.intersect.anno.muts.tmp2" $CANCERDATA $CONVERT >  "${datafile}.filter.intersect.anno.muts.norm.anno.txt" || { echo "ABORT: ERROR on line $LINENO in $PROG "; exit 1; }
OK $LINENO

## remove indels with <14 reads of raw coverage in the normal
echo "================= [Annotate] remove indels with <14 reads in normal"
#cat "${datafile}.filter.intersect.anno.muts.norm.anno.txt" | awk -F'\t' '{if($21>=14) print}' > "${datafile}.filtered.anno.txt"
awk -F'\t' '{if($21>=14) print}' "${datafile}.filter.intersect.anno.muts.norm.anno.txt" > "${datafile}.filtered.anno.txt"

### clean up intermediate files
echo "================= [Annotate] delete intermediate files"
rm -f "${datafile}.filter"
rm -f "${datafile}.filter".*
rm -f "${datafile}.tmp"*

echo -n "$PROG is done on "
date
