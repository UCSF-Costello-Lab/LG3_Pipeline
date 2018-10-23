SHELL:=/bin/bash

## Location of software and resource annotation on TIPCC
LG3_HOME_HIDE:=/home/jocostello/shared/LG3_Pipeline_HIDE


.PHONY: test

check: check_misc check_pbs check_sh check_r check_demo

check_pbs:
	shellcheck *.pbs

check_sh:
	shellcheck bin/lg3*
	shellcheck FilterMutations/*.sh
	shellcheck -x scripts/*.sh

check_r:
	@Rscript -e "for (f in dir('scripts', pattern = '[.]R$$', full.names = TRUE)) tryCatch(parse(f), error = function(ex) stop('Failed to parse R file: ', f, call. = FALSE))"

check_demo:
	shellcheck runs_demo/_run_*

check_misc:
	@echo "Miscellaneous code inspections:"
	@echo "- Assert no hardcoded email address"
	@ ! grep -qE "[a-zA-Z]@[a-zA-Z]"  *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*
	@echo "- Assert no hardcoded /LG3/ project paths"
	@ ! grep -qE "/LG3/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} 
	@echo "- Assert no /data/.. paths"
	@ ! grep -qE "[^a-zA-Z]/data/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*
	@echo "- Assert no /costellolab/.. paths"
	@ ! grep -qE "/costellolab/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} 
	@echo "- Assert no /home/jocostello/shared/LG3_Pipeline"
	@ ! grep -qE "/home/jocostello/shared/LG3_Pipeline" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*
	@echo "- Assert no /home/jocostello/.. paths"
	@ ! grep -qE "[^a-zA-Z]/home/jocostello/" *.pbs runs_demo/_run_* scripts/*.{py,R,sh} FilterMutations/*.{py,sh} bin/lg3*


setup:
	ln -fs $(LG3_HOME_HIDE)/resources .
	ln -fs $(LG3_HOME_HIDE)/tools .
	ln -fs $(LG3_HOME_HIDE)/AnnoVar .
	ln -fs $(LG3_HOME_HIDE)/pykent .
