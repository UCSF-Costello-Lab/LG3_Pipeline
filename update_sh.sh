#!/usr/bin/env bash

## Background: https://github.com/UCSF-Costello-Lab/LG3_Pipeline/issues/3

DEBUG=false

## Make sure to work with the original files
git checkout -- scripts/*.sh

[[ $DEBUG ]] || make check_sh || { echo "ERROR: 'make check_sh' failed on fresh files"; exit 1; }

## Inject 'Configuration' section on top of each script
## directly after the shebang
sed -i -e '/#![/]/a\' -e '\n### Configuration\n' scripts/*.sh

[[ $DEBUG ]] || make check_sh || { echo "ERROR: 'make check_sh' failed on fresh files"; exit 1; }

## Inject LG3_HOME in the Configuration section
sed -i -e '/### Configuration/a\' -e 'LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}' scripts/*.sh

## Inject LG3_OUTPUT_DIR in the Configuration section
sed -i -e '/^LG3_HOME/a\' -e 'LG3_OUTPUT_DIR=${LG3_OUTPUT_DIR:-/costellolab/data1/jocostello/LG3}' scripts/*.sh

## Inject SCRATCHDIR in the Configuration section
sed -i -e '/^LG3_OUTPUT_DIR/a\' -e 'SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}}' scripts/*.sh

## Drop project=LG3
sed -i '/project=LG3/d' scripts/*.sh

## Inject 'project' in the Configuration section
sed -i -e '/^LG3_OUTPUT_DIR/a\' -e 'project=LG3' scripts/*.sh

## Inject LG3_PROJECT_DIR in the Configuration section or after
## the last occurance of 'project='
for ff in scripts/*.sh; do gawk -i inplace 'FNR==NR{ if (/project=/) p=NR; next} 1; FNR==p{ print "LG3_PROJECT_DIR=${LG3_PROJECT_DIR:-/costellolab/data1/jocostello/${project:?}}" }' $ff $ff; done

## TAB -> 8 spaces
sed -i -E 's|\t|        |g' scripts/*.sh

## Inject quoted usages of ${LG3_HOME}
sed -i 's|/home/jocostello/shared/LG3_Pipeline/|${LG3_HOME}/|g' scripts/*.sh
sed -i -E 's|^[$][{]LG3_HOME[}]/([^ ]*)|"${LG3_HOME}/\1"|g' scripts/*.sh
sed -i -E 's| [$][{]LG3_HOME[}]/([^ ]*)| "${LG3_HOME}/\1"|g' scripts/*.sh

## Quote usages of variables that now depend on LG3_HOME
sed -i -E 's|^[$]BIN/([^ ]+)|"$BIN/\1"|g' scripts/*.sh
sed -i -E 's| [$]BIN/([^ ]+)| "$BIN/\1"|g' scripts/*.sh
sed -i -E 's| [$]BWA_INDEX | "$BWA_INDEX" |g' scripts/*.sh
sed -i -E 's| [$]BEDMAKER | "$BEDMAKER" |g' scripts/*.sh
sed -i -E 's| [$]RNAANNO | "$RNAANNO" |g' scripts/*.sh
sed -i -E 's| [$]GATK | "$GATK" |g' scripts/*.sh
sed -i -E 's| [$]REF | "$REF" |g' scripts/*.sh
sed -i -E 's|[$][{]REF[}]|"${REF}"|g' scripts/*.sh
sed -i -E 's| [$]PICARD/([^ ]*)| "$PICARD/\1"|g' scripts/*.sh
sed -i -E 's| [$]WIGFIXER | "$WIGFIXER" |g' scripts/*.sh
sed -i -E 's| [$]ANNO_AGILENT | "$ANNO_AGILENT" |g' scripts/*.sh
sed -i -E 's| [$]CALCULATE | "$CALCULATE" |g' scripts/*.sh
sed -i -E 's| [$]GENOME | "$GENOME" |g' scripts/*.sh
sed -i -E 's| [$]MUTECT | "$MUTECT" |g' scripts/*.sh
sed -i -E 's| [$]DBSNP | "$DBSNP" |g' scripts/*.sh
sed -i -E 's| [$]REORDER | "$REORDER" |g' scripts/*.sh
sed -i -E 's| [$]COSMICDATA | "$COSMICDATA" |g' scripts/*.sh
sed -i -E 's| [$]KINASEDATA | "$KINASEDATA" |g' scripts/*.sh
sed -i -E 's| [$]CANCERDATA | "$CANCERDATA" |g' scripts/*.sh
sed -i -E 's| [$]CONVERT | "$CONVERT" |g' scripts/*.sh
sed -i -E 's| [$]PBS$| "$PBS"|g' scripts/*.sh
sed -i -E 's|^[$]ANNOVAR/([^ ]*)|"$ANNOVAR/\1"|g' scripts/*.sh
sed -i -E 's| [$]ANNDB | "$ANNDB" |g' scripts/*.sh
sed -i -E 's| [$]THOUSAND | "$THOUSAND" |g' scripts/*.sh

sed -i -e '/source "${LG3_HOME}[/]FilterMutations[/]filter.profile.sh"/i \        # shellcheck source=FilterMutations/filter.profile.sh' scripts/MutDet.sh
sed -i -e '/source "${LG3_HOME}[/]FilterMutations[/]filter.profile.sh"/i \        # shellcheck source=FilterMutations/filter.profile.sh' scripts/Rob-MutDet-hg18.sh

[[ $DEBUG ]] || make check_sh || { echo "ERROR: 'make check_sh' failed after LG3_HOME"; exit 1; }

## Inject quoted usages of ${LG3_PROJECT_DIR}
sed -i 's|/costellolab/data1/jocostello/${project}/|${LG3_PROJECT_DIR}/|g' scripts/*.sh

[[ $DEBUG ]] || make check_sh || { echo "ERROR: 'make check_sh' failed after LG3_PROJECT_DIR"; exit 1; }

## Inject quoted usages of ${LG3_OUTPUT_DIR}
sed -i 's|/costellolab/data1/jocostello/LG3/|${LG3_OUTPUT_DIR}/|g' scripts/*.sh
sed -i -E 's|([^o]) [$][{]LG3_OUTPUT_DIR[}]/([^ ]*)|\1 "${LG3_OUTPUT_DIR}/\2"|g' scripts/*.sh

[[ $DEBUG ]] || make check_sh || { echo "ERROR: 'make check_sh' failed after LG3_OUTPUT_DIR"; exit 1; }

## Manual: Drop unused code; use $USER instead of $U
sed -i '/U=$(whoami)/d' scripts/*.sh

[[ $DEBUG ]] || make check_sh || { echo "ERROR: 'make check_sh' failed after U -> USER"; exit 1; }

## Inject quoted usages of ${SCRATCHDIR}
sed -i -E 's|([^-])/scratch/jocostello|\1${SCRATCHDIR}|g' scripts/*.sh
sed -i -E 's|([^-])/scratch/[$]USER|\1${SCRATCHDIR}|g' scripts/*.sh
sed -i -E 's|([^-])/scratch/[$]U/|\1${SCRATCHDIR}/|g' scripts/*.sh
sed -i -E 's|^TMP="/scratch"|TMP=${SCRATCHDIR}|g' scripts/*.sh
sed -i -E 's|([^"])[$][{]TMP[}]|\1"${TMP}"|g' scripts/*.sh

[[ $DEBUG ]] || make check_sh || { echo "ERROR: 'make check_sh' failed after SCRATCHDIR"; exit 1; }

## Manual source /home/jocostello/.bashrc -> source "${LG3_HOME}/.bashrc"
sed -i -E 's|^source /home/jocostello/.bashrc|source "${LG3_HOME}/.bashrc"|g' scripts/*.sh
sed -i -e '/source "${LG3_HOME}[/].bashrc"/i # shellcheck source=.bashrc' scripts/*.sh

## VALIDATION: Should be empty
res=$(grep -E '[$]U[^S]' scripts/*.sh)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## VALIDATION: Should be empty
res=$(grep -F '${project]' scripts/*.sh)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## VALIDATION: Should be empty
res=$(grep -E "[^-]/scratch" scripts/*.sh)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## Manual: Assume 'patient_ID_conversions.txt' in working directory
sed -i 's|conv=/costellolab/data1/mazort/LG3/exome/patient_ID_conversions.txt|conv=patient_ID_conversions.txt|g' scripts/chk_mutdet.sh

## VALIDATION: Should be empty
res=$(grep -E "[^-]/costellolab" scripts/*.sh)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## VALIDATION: Should be empty
res=$(grep -E "[^-]/home/jocostello" scripts/*.sh)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## REMAINING: Remaining hardcoded paths
grep -E "[^-]/home" scripts/*.sh


## FINAL CHECK
make check_sh || { echo "ERROR: Final 'make check_sh' failed"; exit 1; }
