.EXPORT_ALL_VARIABLES:

SHELL:=/bin/bash

LG3_HOME:=$(shell dirname $(CURDIR))
LG3_HOME_HIDE:=/home/jocostello/shared/LG3_Pipeline_HIDE
LG3_TEST_DATA_DIR:=/costellolab/data1/shared/LG3_Pipeline/example_data/rawdata
TEST_SUFFIX:=t
TEST_SAMPLES:=Z00599$(TEST_SUFFIX) Z00600$(TEST_SUFFIX) Z00601$(TEST_SUFFIX)
TEST_NORMAL:=Z00599$(TEST_SUFFIX)
TEST_PATIENT:=Patient157$(TEST_SUFFIX)
TEST_LG3_CHASTITY_FILTERING:=false

.PHONY: test

debug:
	@echo "LG3_HOME: $$LG3_HOME (hardcoded to parent directory)"
	@echo "EMAIL: $$EMAIL"
	@echo "TEST_SUFFIX=$$TEST_SUFFIX (may be empty)"
	@echo "TEST_SAMPLES=$$TEST_SAMPLES"
	@echo "TEST_NORMAL=$$TEST_NORMAL"
	@echo "TEST_PATIENT=$$TEST_PATIENT"
	@echo "TEST_LG3_CHASTITY_FILTERING=$$TEST_LG3_CHASTITY_FILTERING"

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

setup: setup-annotation
	cp ../runs_demo/_run_Trim .
	cp ../runs_demo/_run_Align_gz .
	cp ../runs_demo/_run_Recal .
	cp ../runs_demo/_run_Pindel .
	cp ../runs_demo/_run_MutDet .
	cp ../runs_demo/_run_PostMut .

step3: setup
	LG3_INPUT_ROOT=rawdata \
	LG3_OUTPUT_ROOT=output \
	DIROUT=output \
	TG=/home/shared/cbc/software_frozen/20180907-LG3_Pipeline/TrimGalore-0.4.4/trim_galore \
	SAMPLES="$(TEST_SAMPLES)" \
	./_run_Trim

step3-validate:
	SAMPLES="$(TEST_SAMPLES)" \
	Rscript ./validate_trim.R

step4-setup: setup
	ln -fs $${PWD}/tools $${LG3_HOME}/  ## FIXME: AD HOC
	ln -fs $${PWD}/resources $${LG3_HOME}/  ## FIXME: AD HOC

step4: setup step4-setup step3-validate
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	SAMPLES="$(TEST_SAMPLES)" \
	LG3_CHASTITY_FILTERING=$(TEST_LG3_CHASTITY_FILTERING) \
	./_run_Align_gz

step4-validate:
	SAMPLES="$(TEST_SAMPLES)" \
	Rscript ./validate_align.R

step5-setup: setup
	ln -fs $${PWD}/AnnoVar $${LG3_HOME}/  ## FIXME: AD HOC
	ln -fs $${PWD}/pykent $${LG3_HOME}/  ## FIXME: AD HOC (needed here?)

step5: setup step5-setup step4-validate
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	SAMPLES="$(TEST_SAMPLES)" \
	NORMAL=$(TEST_NORMAL) \
	PATIENT=$(TEST_PATIENT) \
	ILIST=resources/SeqCap_EZ_Exome_v3_capture.interval_list \
        ./_run_Recal

step5-validate:
	PATIENT=$(TEST_PATIENT) \
	Rscript ./validate_recal.R

step6a-setup: setup
	ln -fs $${PWD}/AnnoVar $${LG3_HOME}/  ## FIXME: AD HOC
	ln -fs $${PWD}/pykent $${LG3_HOME}/  ## FIXME: AD HOC (needed here?)

step6a: setup step6a-setup step5-validate
	## FIXME FIRST: ${LG3_OUTPUT_ROOT}/LG3/exome/patient_ID_conversions.txt
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	PATIENT=$(TEST_PATIENT) \
	CONV=patient_ID_conversions.txt \
	./_run_Pindel

step6a-validate:

step6b-setup: setup
	ln -fs $${PWD}/pykent $${LG3_HOME}/  ## FIXME: AD HOC (correct?)

step6b: setup step6a-setup
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	PATIENT=$(TEST_PATIENT) \
	CONV=patient_ID_conversions.txt \
	./_run_MutDet

step6b-validate:

step7-setup: setup
	ln -fs $${PWD}/pykent $${LG3_HOME}/  ## FIXME: AD HOC (correct?)

step7: setup step7-setup
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	PATIENT=$(TEST_PATIENT) \
	CONV=patient_ID_conversions.txt \
	./_run_PostMut
