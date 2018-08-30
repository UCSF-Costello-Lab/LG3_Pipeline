#!/bin/bash
TG=/home/ismirnov/install/trim_galore/v0.4.4/trim_galore
#CUTADAPT=/opt/Python/Python-2.7.9/bin/cutadapt ### Problem !
CUTADAPT=/opt/Python/Python-2.7.3/bin/cutadapt
QTY=20
LEN=20
STRINGENCY=1

if [ $# -lt 2 ]; then
	echo "Run trim_galore in paired mode on gzipped fastq files using Illumina universal adapter"
	echo "Usage: $0 [ -quality=$QTY -length=$LEN -stringency=$STRINGENCY] 1.fastq.gz 2.fastq.gz"
	exit 1
fi

#### Parse optional args
while [ -n "$1" ]; do
case $1 in
    -q*=*) QTY=${1#*=};shift 1;;
    -l*=*) LEN=${1#*=};shift 1;;
    -s*=*) STRINGENCY=${1#*=};shift 1;;
    -*) echo "error: no such option $1";exit 1;;
    *)  break;;
esac
done

FQ1=$1
FQ2=$2

if [ ! -r "$FQ1" ] || [ ! -r "$FQ2" ]; then
	echo "[trim_galore] ERROR: Can't open $FQ1 or $FQ2 !"
	exit 1
fi

### Default: --length 20 --quality 20 --stringency 1
### --fastqc
time $TG --paired --quality "$QTY" --length "$LEN" --stringency 1 --path_to_cutadapt $CUTADAPT --illumina "$FQ1" "$FQ2" || { echo "[trim_galore] ERROR: trim_galore FAILED"; exit 1; }

exit 0
