SHELL:=/bin/bash

## Location of software and resource annotation on TIPCC
LG3_HOME_HIDE:=/home/jocostello/shared/LG3_Pipeline_HIDE


.PHONY: test

check: check_use_utils_instead check_hardcoded check_shellcheck check_r

check_shellcheck: check_pbs check_sh check_demo check_tests check_conf

check_tests:
	@echo "* Validating test scripts"
	shellcheck -x tests/*.sh

check_pbs:
	@echo "* Validating PBS scripts"
	shellcheck -x *.pbs

check_sh:
	@echo "* Validating shell scripts"
	shellcheck -x bin/lg3*
	shellcheck FilterMutations/*.sh
	shellcheck -x scripts/*.sh

check_conf:
	@echo "* Validating configuration scripts"
	shellcheck --shell=bash --exclude=2034 lg3.conf

check_demo:
	@echo "* Validating run scripts"
	shellcheck -x runs_demo/_run_*

check_r:
	@echo "* Validating R syntax"
	@!(which Rscript &> /dev/null) || Rscript -e "for (f in dir('scripts', pattern = '[.]R$$', full.names = TRUE)) { tryCatch(parse(f), error = function(ex) stop('Failed to parse R file: ', f, call. = FALSE)) }"

check_hardcoded:
	@echo "* Miscellaneous code inspections"
	@echo "  - Assert no hardcoded email address"
	@ ! grep -qE "[a-zA-Z]@[a-zA-Z]"  *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*
	@echo "  - Assert no hardcoded /LG3/ project paths"
	@ ! grep -qE "/LG3/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} 
	@echo "  - Assert no /data/.. paths"
	@ ! grep -qE "[^a-zA-Z]/data/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*
	@echo "  - Assert no /costellolab/.. paths"
	@ ! grep -qE "/costellolab/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} 
	@echo "  - Assert no /home/jocostello/shared/LG3_Pipeline"
	@ ! grep -qE "/home/jocostello/shared/LG3_Pipeline" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*
	@echo "  - Assert no /home/jocostello/.. paths"
	@ ! grep -qE "[^a-zA-Z]/home/jocostello/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*

check_use_utils_instead:
	@echo "* Coding style"
	@echo "  - Assert no calls to 'exit' (use 'error' function instead)"
	@ ! grep -qE "exit [1-9]" *.pbs runs_demo/_run_* scripts/*.sh FilterMutations/*.sh # bin/lg3*
#	@ ! grep -qE "exit [1-9]" bin/lg3*
	@echo "  - Assert no calls to 'mkdir' or 'cd' (use 'make_dir' and 'change_dir' instead)"
	@ ! grep -qE "(mkdir|cd) " --exclude="scripts/utils.sh" *.pbs runs_demo/_run_* scripts/*.sh FilterMutations/*.sh # bin/lg3*
	@echo "  - Assert no [[ -(d|f|x) ... ]] assertions (use 'assert_file_exists', 'assert_directory_exists' etc. instead)"
	@ ! grep -qE "[[][[] -(d|f|x) .* [|][|] " --exclude="scripts/utils.sh" *.pbs runs_demo/_run_* scripts/*.sh FilterMutations/*.sh
	@echo "  - Assert no echo 'ERROR/WARNING' output (use 'error' and 'warn' instead)"
	@ ! grep -qE '"(ERROR|WARNING)' --exclude="scripts/utils.sh" *.pbs runs_demo/_run_* scripts/*.sh FilterMutations/*.sh

test:
	${LG3_HOME}/tests/error.sh
	${LG3_HOME}/tests/warn.sh

setup:
	ln -fs $(LG3_HOME_HIDE)/resources .
	ln -fs $(LG3_HOME_HIDE)/tools .
	ln -fs $(LG3_HOME_HIDE)/AnnoVar .
	ln -fs $(LG3_HOME_HIDE)/pykent .
	ln -fs /home/jocostello/shared/exomeQualityPlots .
