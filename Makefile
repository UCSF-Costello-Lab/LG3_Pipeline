SHELL:=/bin/bash

## Location of software and resource annotation on TIPCC
LG3_HOME_HIDE:=/home/jocostello/shared/LG3_Pipeline_HIDE


.PHONY: test

check: check_pbs check_sh check_demo

check_pbs:
	shellcheck *.pbs

check_sh:
	shellcheck -x --exclude=SC1091 scripts/*.sh

check_demo:
	shellcheck runs_demo/_run_*

setup:
	ln -fs $(LG3_HOME_HIDE)/resources .
	ln -fs $(LG3_HOME_HIDE)/tools .
	ln -fs $(LG3_HOME_HIDE)/AnnoVar .
	ln -fs $(LG3_HOME_HIDE)/pykent .
