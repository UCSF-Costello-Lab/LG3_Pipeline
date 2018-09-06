.EXPORT_ALL_VARIABLES:

SHELL:=/bin/bash

LG3_HOME:=$(shell dirname $(CURDIR))
LG3_OUTPUT_DIR:=output
LG3_HOME_HIDE:=/home/jocostello/shared/LG3_Pipeline_HIDE
LG3_TEST_DATA_DIR:=/costellolab/data1/ismirnov/tmp

.PHONY: test

debug:
	@echo "LG3_HOME: $$LG3_HOME (hardcoded to parent directory)"
	@echo "EMAIL: $$EMAIL"
	@echo "LG3_OUTPUT_DIR: $$LG3_OUTPUT_DIR (hardcoded)"
	@echo "LG3_PROJECT_DIR: $$LG3_PROJECT_DIR"

setup: setup-P157

setup-annotation:
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

step1-P157: setup-P157
	_run_Trim_P157
