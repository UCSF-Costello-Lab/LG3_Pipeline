#!/bin/bash

LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}
LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}
PROJECT=${PROJECT:-LG3}
CONV=${CONV:-patient_ID_conversions.tsv}

#BAM_SUFF=bwa.realigned.rmDups.recal.bam
BAM_SUFF=bwa.realigned.rmDups.recal.insert_size_metrics

### Colors and colored messages
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[0;33m'
NOC='\033[0m'
OK="$GRN OK$NOC"
ERR="$RED missing$NOC"
SEP="$YEL******$NOC"

FQ=false
TRIM=false
BWA=false
REC=false
GL=false
PINDEL=false
MUT=false
COMB=false

wcl() {
	grep -vc "^#" "$1" 
	#grep -v "^#" $1 | wc -l
}

if [ $# -eq 0 ]; then
	echo "Usage: $0 [ -conv=$CONV -bam=$BAM_SUFF -fastq=$FQ -trim=$TRIM -bwa=$BWA -recal=$REC -germline=$GL -pindel=$PINDEL -mutect=$MUT -combined=$COMB ] PatientX PatientY ..."
	exit 1
fi
#### Parse optional args
while [ -n "$1" ]; do
case $1 in
    -conv*=*) CONV=${1#*=};shift 1;;
    -bam*=*) BAM_SUFF=${1#*=};shift 1;;
    -tr*=*) TRIM=${1#*=};shift 1;;
    -f*=*) FQ=${1#*=};shift 1;;
    -bwa*=*) BWA=${1#*=};shift 1;;
    -rec*=*) REC=${1#*=};shift 1;;
    -g*=*) GL=${1#*=};shift 1;;
    -p*=*) PINDEL=${1#*=};shift 1;;
    -m*=*) MUT=${1#*=};shift 1;;
    -comb*=*) COMB=${1#*=};shift 1;;
    -*) echo "error: no such option $1";exit 1;;
    *)  break;;
esac
done


echo -e "Checking output for project ${PROJECT}"
echo "Patient/samples table ${CONV}"
echo "BAM suffix ${BAM_SUFF}"

for PATIENT in "$@"
do
	normid="$ERR"
	echo -e -n "$SEP Checking ${YEL}${PATIENT}${NOC}"
	## Pull out PATIENT specific conversion info
	grep -w "${PATIENT}" "${CONV}" > "${PATIENT}.temp.conversions.txt"
	## Get normal ID
	while IFS=$'\t' read -r ID _ _ SAMP
	do
		if [ "$SAMP" = "Normal" ]; then
			normid=${ID}
			break
		fi
	done < "${PATIENT}.temp.conversions.txt"
	echo -e " Normal: $normid"

if $FQ ; then
	WORKDIR=rawdata
   ## Cycle through samples and check fastq files
   while IFS=$'\t' read -r ID _ _ SAMP
   do
      ### Expected output
      OUT=${WORKDIR}/${ID}_R1.fastq.gz
      if [ -s "$OUT" ]; then
         echo -e "Fastq $ID $OK"
      else
         echo -e "Fastq $ID $ERR"
      fi
   done < "${PATIENT}.temp.conversions.txt"
fi

if $TRIM ; then
	WORKDIR=${LG3_OUTPUT_ROOT}
   ## Cycle through samples and check trim-galore output
   while IFS=$'\t' read -r ID _ _ SAMP
   do
		### Expected output
		OUT=${WORKDIR}/${ID}-trim/${ID}-trim_R1.fastq.gz
		if [ -s "$OUT" ]; then
			echo -e "Trim $ID $OK"
		else
			echo -e "Trim $ID $ERR"
		fi
	done < "${PATIENT}.temp.conversions.txt"
fi

if $BWA ; then
	WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/exomes
   ## Cycle through samples and check BWA
   while IFS=$'\t' read -r ID _ _ SAMP
   do
		### Expected output
		OUT=${WORKDIR}/${ID}/${ID}.trim.bwa.sorted.flagstat
		if [ -s "$OUT" ]; then
			echo -e "BWA $ID $OK"
		else
			echo -e "BWA $ID $ERR"
		fi
	done < "${PATIENT}.temp.conversions.txt"
fi

if $REC ; then
	WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/exomes_recal/${PATIENT}
   ## Cycle through samples and check Recal output
   while IFS=$'\t' read -r ID _ _ SAMP
   do
		### Expected output
		OUT=${WORKDIR}/${ID}.$BAM_SUFF
		if [ -s "$OUT" ]; then
			echo -e "Recal $ID $OK"
		else
			echo -e "Recal $ID $ERR"
		fi
	done < "${PATIENT}.temp.conversions.txt"
fi

if $GL ; then
	OUT=${WORKDIR}/germline/${PATIENT}.UG.snps.vcf
	if [ -s "$OUT" ]; then
		LCNT=$(wcl "$OUT")
		echo -e "UG $OK ${YEL}${LCNT}${NOC}"
	else
		echo -e "UG $ERR"
	fi

   ## Cycle through tumors and check Germline output
   while IFS=$'\t' read -r ID _ _ SAMP
   do
		if [ "$ID" == "$normid" ]; then continue; fi

		### Expected output
		OUT=${WORKDIR}/germline/NOR-${normid}_vs_${ID}.germline
		if [ -s "$OUT" ]; then
			echo -e "Germline $ID $OK"
		else
			echo -e "Germline $ID $ERR"
		fi
	done < "${PATIENT}.temp.conversions.txt"
fi

if $PINDEL ; then
	WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/pindel/${PATIENT}_pindel
	## Expected output:
	OUT=${WORKDIR}/${PATIENT}.indels.filtered.anno.txt
	if [ -s "$OUT" ]; then
		LCNT=$(wcl "$OUT")
		echo -e "Pindel $OK ${YEL}${LCNT}${NOC}"
	else
		echo -e "Pindel $ERR"
	fi
fi

if $MUT ; then
	WORKDIR=${LG3_OUTPUT_ROOT}/${PROJECT}/mutations/${PATIENT}_mutect
	## Cycle through tumors and check MUTECT output
	while IFS=$'\t' read -r ID _ _ SAMP
	do
		if [ "$SAMP" = "Normal" ]; then
			continue
		elif [ "${SAMP:0:2}" = "ML" ]; then
			samp_label="ML"
		elif [ "${SAMP:0:3}" = "GBM" ]; then
			samp_label="GBM"
		elif [ "${SAMP:0:3}" = "Pri" ]; then
			samp_label="TUM"
		elif [ "${SAMP:0:3}" = "Tum" ]; then
			samp_label="TUM"
		elif [ "${SAMP:0:11}" = "Recurrence1" ]; then
			samp_label="REC1"
		elif [ "${SAMP:0:11}" = "Recurrence2" ]; then
			samp_label="REC2"
		elif [ "${SAMP:0:11}" = "Recurrence3" ]; then
			samp_label="REC3"
        	elif [ "${SAMP:0:5}" == "tumor" ]; then
                	samp_label="unkTUM"
		else
			samp_label="TUM"
		fi
	
		## Expected output:
		OUT=${WORKDIR}/${PATIENT}.NOR-${normid}__${samp_label}-${ID}.annotated.mutations
		if [ -s "$OUT" ]; then
			LCNT=$(wcl "$OUT")
			echo -e "Mutect $ID $OK ${YEL}${LCNT}${NOC}"
		else
			echo -e "Mutect $ID $ERR"
		fi
	
	done < "${PATIENT}.temp.conversions.txt"
fi	
	## Delete PATIENT specific conversion file
	rm "${PATIENT}.temp.conversions.txt"


if $COMB ; then
	WORKDIR1=${LG3_OUTPUT_ROOT}/${PROJECT}/MutInDel
	## Expected output: 
	OUT=${WORKDIR1}/${PATIENT}.R.mutations
	if [ -s "$OUT" ]; then
		LCNT=$(wcl "$OUT")
		echo -e "MutCombine $OK ${YEL}${LCNT}${NOC}"
	else
		echo -e "MutCombine $ERR"
	fi
	
	WORKDIR2=${LG3_OUTPUT_ROOT}/${PROJECT}/MAF
	OUT=${WORKDIR2}/${PATIENT}_MAF/${PATIENT}.Normal.MAF.txt	
	if [ -s "$OUT" ]; then
		echo -e "MAF $OK"
	else
		echo -e "MAF $ERR"
	fi
	
	WORKDIR3=${LG3_OUTPUT_ROOT}/${PROJECT}/MAF
	res=true
	for ff in $(ls ${WORKDIR3}/${PATIENT}_plots/${PATIENT}.LOH*.pdf); do
	    if [ ! -s "$OUT" ]; then
		res=false
		break
	    fi
	done
	if [ $res ]; then
		echo -e "LOH plots $OK"
	else
		echo -e "LOH plots $ERR"
	fi
fi	
done
