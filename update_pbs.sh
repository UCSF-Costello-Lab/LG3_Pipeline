#!/usr/bin/env bash

## Background: https://github.com/UCSF-Costello-Lab/LG3_Pipeline/issues/3

DEBUG=false

## Make sure to work with the original files
git checkout -- *.pbs

## Inject 'Configuration' section on top of each PBS script
## directly after the '#PBS ' header
for ff in *.pbs; do gawk -i inplace 'FNR==NR{ if (/#PBS/) p=NR; next} 1; FNR==p{ print "\n### Configuration\n" }' $ff $ff; done

## Inject LG3_HOME in the Configuration section
sed -i -e '/### Configuration/a\' -e 'LG3_HOME=${LG3_HOME:-/home/jocostello/shared/LG3_Pipeline}' *.pbs

## Inject LG3_OUTPUT_ROOT in the Configuration section
sed -i -e '/^LG3_HOME/a\' -e 'LG3_OUTPUT_ROOT=${LG3_OUTPUT_ROOT:-/costellolab/data1/jocostello}' *.pbs

## Inject SCRATCHDIR in the Configuration section
sed -i -e '/^LG3_OUTPUT_ROOT/a\' -e 'SCRATCHDIR=${SCRATCHDIR:-/scratch/${USER:?}}' *.pbs

## Inject LG3_DEBUG in the Configuration section
sed -i -e '/^SCRATCHDIR/a\' -e 'LG3_DEBUG=${LG3_DEBUG:-true}' *.pbs

sed -i -e '/^LG3_DEBUG/a\' -e '\n### Debug\nif [[ $LG3_DEBUG ]]; then\n  echo "LG3_HOME=$LG3_HOME"\n  echo "LG3_OUTPUT_ROOT=$LG3_OUTPUT_ROOT"\n  echo "SCRATCHDIR=$SCRATCHDIR"\n  echo "PWD=$PWD"\n  echo "USER=$USER"\nfi\n' *.pbs

## Inject quoted usages of ${LG3_HOME}
sed -i 's|/home/jocostello/shared/LG3_Pipeline/|${LG3_HOME}/|g' *.pbs
sed -i -E 's|^[$][{]LG3_HOME[}]/([^ ]*)|"${LG3_HOME}/\1"|g' *.pbs
## Quote usages of variables that now depend on LG3_HOME
sed -i -E 's|^[$]BIN/([^ ]+)|"$BIN/\1"|g' *.pbs

[[ $DEBUG ]] || make check_pbs || { echo "ERROR: 'make check_pbs' failed after LG3_HOME"; exit 1; }

## Inject quoted usages of ${LG3_OUTPUT_ROOT}/LG3
sed -i 's|/costellolab/data1/jocostello/LG3/|${LG3_OUTPUT_ROOT}/LG3/|g' *.pbs

[[ $DEBUG ]] || make check_pbs || { echo "ERROR: 'make check_pbs' failed after LG3_OUTPUT_DIR/LG3"; exit 1; }

## Inject quoted usages of ${LG3_OUTPUT_ROOT}/${PROJ}
sed -i 's|/costellolab/data1/jocostello/${PROJ}/|${LG3_OUTPUT_ROOT}/${PROJ}/|g' *.pbs

[[ $DEBUG ]] || make check_pbs || { echo "ERROR: 'make check_pbs' failed after LG3_OUTPUT_ROOT/PROJ"; exit 1; }

sed -i -E 's|([^o]) [$][{]LG3_OUTPUT_ROOT[}]/([^ ]*)|\1 "${LG3_OUTPUT_ROOT}/\2"|g' *.pbs

[[ $DEBUG ]] || make check_pbs || { echo "ERROR: 'make check_pbs' failed after quoting LG3_OUTPUT_ROOT"; exit 1; }

## Manual: Drop unused code; use $USER instead of $U
sed -i '/U=$(whoami)/d' *.pbs
sed -i -E 's/[$]U([^S])/$USER\1/g' *.pbs

[[ $DEBUG ]] || make check_pbs || { echo "ERROR: 'make check_pbs' failed after U -> USER"; exit 1; }

## Inject quoted usages of ${SCRATCHDIR}
sed -i -E 's|([^-])/scratch/jocostello|\1${SCRATCHDIR}|g' *.pbs
sed -i -E 's|([^-])/scratch/[$]USER|\1${SCRATCHDIR}|g' *.pbs
sed -i -E 's|([^-])/scratch/[$][{]PREFIX[}]|\1${SCRATCHDIR}/${PREFIX}|g' *.pbs
sed -i -E 's|([^-])/scratch/[$]U/[$][{]PREFIX[}]|\1${SCRATCHDIR}/${PREFIX}|g' *.pbs
sed -i -E 's|([^-])/scratch/[$]U/[$][{]PATIENT[}]|\1${SCRATCHDIR}/${PATIENT}|g' *.pbs
sed -i -E 's|([^-])/scratch/[$]U|\1${SCRATCHDIR}|g' *.pbs
#sed -i -E 's| [$][{]SCRATCHDIR[}]/([^ ]*)| "${SCRATCHDIR}/\1"|g' *.pbs
sed -i -E 's| [$][{]SCRATCHDIR[}] | "${SCRATCHDIR} "|g' *.pbs
sed -i 's|rm -rf "${SCRATCHDIR}/|rm -rf "${SCRATCHDIR:?}/|g' *.pbs

## Manual: Drop unused code
sed -i '/cd "[/]scratch" ||/d' Align_bam.pbs

## Manual: Tweak message
sed -i 's|Cleaning /scratch ...|Cleaning ${SCRATCHDIR} ...|' Recal_bigmem.pbs

[[ $DEBUG ]] || make check_pbs || { echo "ERROR: 'make check_pbs' failed after SCRATCHDIR"; exit 1; }


## VALIDATION: Should be empty
res=$(grep -E "[^-]/costellolab" *.pbs)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## VALIDATION: Should be empty
res=$(grep -E "[^-]/scratch" *.pbs)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## VALIDATION: Should be empty
res=$(grep -E '[$]U[^S]' *.pbs)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## VALIDATION: Should be empty
res=$(grep -E "[^-]/home/jocostello" *.pbs)
echo "$res"
[[ -z "$res" ]] || { echo "ERROR: Hardcoded paths still found"; exit 1; }

## REMAINING: Remaining hardcoded paths
grep -E "[^-]/home" *.pbs

## FINAL CHECK
make check_pbs || { echo "ERROR: Final 'make check_pbs' failed"; exit 1; }
