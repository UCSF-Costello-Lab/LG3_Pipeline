SHELL:=/bin/bash

.PHONY: test

check:
	shellcheck -x *.pbs
	shellcheck -x scripts/*.sh
