
FD=$1
Z=$2

FQC=/home/ismirnov/install/fastqc/FastQC_v0.11.5/fastqc

cd $FD


F1=${Z}_R1.fastq.gz
F2=${Z}_R2.fastq.gz

#time $FQC -k 10 -t 10 $F1 $F2
time $FQC -t 10 $F1 $F2
