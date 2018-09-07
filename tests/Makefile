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
ifeq ($(wildcard $(LG3_OUTPUT_ROOT)/.),)
	@echo "ERROR: Directory $(LG3_OUTPUT_ROOT)/ is missing"
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
	cp ../runs_demo/_run_Trim_P157 .
	cp ../runs_demo/_run_Align_gz_P157 .
	cp ../runs_demo/_run_Recal_P157_3 .
	cp ../runs_demo/_run_Pindel_157 .
	cp ../runs_demo/_run_MutDet_P157 .
	cp ../runs_demo/_run_PostMut_P157 .

setup: setup-P157

step3: setup
	LG3_INPUT_ROOT=rawdata \
	LG3_OUTPUT_ROOT=output \
	DIROUT=output \
	TG=/home/shared/cbc/software_frozen/20180907-LG3_Pipeline/TrimGalore-0.4.4/trim_galore \
	./_run_Trim_P157

step4: setup
	LG3_INPUT_ROOT=output \
	LG3_OUTPUT_ROOT=output \
	./_run_Align_gz_P157
