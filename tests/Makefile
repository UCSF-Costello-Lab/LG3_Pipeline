.EXPORT_ALL_VARIABLES:

SHELL:=/bin/bash

LG3_HOME:=$(shell dirname $(CURDIR))
LG3_HOME_HIDE:=/home/jocostello/shared/LG3_Pipeline_HIDE
LG3_TEST_DATA_DIR:=/costellolab/data1/ismirnov/tmp

.PHONY: test

debug:
	@echo "LG3_HOME: $$LG3_HOME (hardcoded to parent directory)"
	@echo "PROJ: $$PROJ (hardcoded; FIXME: Should not be needed)"
	@echo "EMAIL: $$EMAIL"

setup-assert:
ifeq ($(wildcard output/.),)
	@echo "ERROR: Directory output/ is missing"
	@exit 1
endif

clean: 
	rm -f resources tools AnnoVar pykent rawdata patient_ID_conversions.txt
	rm -f _run_*

setup-annotation: setup-assert
	ln -fs $(LG3_HOME_HIDE)/resources .
	ln -fs $(LG3_HOME_HIDE)/tools .
	ln -fs $(LG3_HOME_HIDE)/AnnoVar .
	ln -fs $(LG3_HOME_HIDE)/pykent .
	## Location of links to FASTQ.gz files
	ln -fs $(LG3_TEST_DATA_DIR) rawdata
	ln -fs ../runs_demo/patient_ID_conversions.demo patient_ID_conversions.txt

setup-P157: setup-annotation
	cp ../runs_demo/_run_Trim .
	cp ../runs_demo/_run_Align_gz .
	cp ../runs_demo/_run_Recal .
	cp ../runs_demo/_run_Pindel .
	cp ../runs_demo/_run_MutDet .
	cp ../runs_demo/_run_PostMut .

setup: setup-P157

step3: setup
	LG3_INPUT_ROOT=rawdata \
	LG3_OUTPUT_ROOT=output \
	DIROUT=output \
	TG=/home/shared/cbc/software_frozen/20180907-LG3_Pipeline/TrimGalore-0.4.4/trim_galore \
	SAMPLES="Z00599 Z00600 Z00601" \
	./_run_Trim

step3-validate:
	SAMPLES="Z00599 Z00600 Z00601" \
	Rscript ./validate_trim.R

step4-setup: setup
	ln -fs $${PWD}/tools $${LG3_HOME}/  ## FIXME: AD HOC
	ln -fs $${PWD}/resources $${LG3_HOME}/  ## FIXME: AD HOC

step4: setup step4-setup step3-validate
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	SAMPLES="Z00599 Z00600 Z00601" \
	./_run_Align_gz

step4-validate:
	SAMPLES="Z00599 Z00600 Z00601" \
	Rscript ./validate_align.R

step5-setup: setup
	ln -fs $${PWD}/AnnoVar $${LG3_HOME}/  ## FIXME: AD HOC
	ln -fs $${PWD}/pykent $${LG3_HOME}/  ## FIXME: AD HOC (needed here?)

step5: setup step5-setup step4-validate
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	SAMPLES="Z00599 Z00600 Z00601" \
	NORMAL=Z00599 \
	PATIENT=Patient157 \
	ILIST=resources/SeqCap_EZ_Exome_v3_capture.interval_list \
        ./_run_Recal

step5-validate:
	PATIENT=Patient157 \
	Rscript ./validate_recal.R

step6a-setup: setup
	ln -fs $${PWD}/AnnoVar $${LG3_HOME}/  ## FIXME: AD HOC
	ln -fs $${PWD}/pykent $${LG3_HOME}/  ## FIXME: AD HOC (needed here?)

step6a: setup step6a-setup step5-validate
	## FIXME FIRST: ${LG3_OUTPUT_ROOT}/LG3/exome/patient_ID_conversions.txt
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	PATIENT=Patient157 \
	PROJ=LG3 \
	CONV=patient_ID_conversions.txt \
	./_run_Pindel

step6a-validate:

step6b-setup: setup
	ln -fs $${PWD}/pykent $${LG3_HOME}/  ## FIXME: AD HOC (correct?)

step6b: setup step6a-setup
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	PATIENT=Patient157 \
	PROJ=LG3 \
	CONV=patient_ID_conversions.txt \
	./_run_MutDet

step6b-validate:
