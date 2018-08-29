SHELL:=/bin/bash

.PHONY: test

check_pbs:
	shellcheck *.pbs

check_sh:
	shellcheck -x scripts/*.sh

check: check_pbs check_sh
