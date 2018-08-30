SHELL:=/bin/bash

.PHONY: test

check: check_pbs check_sh

check_pbs:
	shellcheck *.pbs

check_sh:
	shellcheck -x scripts/*.sh
