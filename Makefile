SHELL:=/bin/bash

.PHONY: test

check: check_pbs check_sh

check_pbs:
	shellcheck --exclude=SC1117 *.pbs

check_sh:
	shellcheck -x --exclude=SC1117 --exclude=SC1091 scripts/*.sh
