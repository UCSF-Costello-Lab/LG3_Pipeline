# LG3_Pipeline

## Version 2018-09-08-9000 (development version)

### SIGNIFICANT CHANGES

 * The pipeline can now be run by any user on the TIPCC compute cluster by
   setting environment variables 'LG3_HOME', 'LG3_OUTPUT_ROOT', and
   'LG3_INPUT_ROOT'. If not set, the default is to use the hardcoded folders
   used in previous versions of the pipeline.

### NEW FEATURES

 * The location of the LG3 Pipeline folder can now set via environment variable
   'LG3_HOME', e.g. `export LG3_HOME=/path/to/LG3_Pipeline`.
  
 * The location of where result files are written can be set via environment
   variable 'LG3_OUTPUT_PATH'.  For example, to output to the folder `output/`
   in the current directory use `export LG3_OUTPUT_PATH=output`. The folder
   will be created, if missing.
  
 * The location of where output files from previous steps in the pipeline is
   located can be set via environment variable 'LG3_INPUT_PATH', which should
   typically be set to the same folder as 'LG3_OUTPUT_PATH', i.e.
   `export LG3_INPUT_PATH=${LG3_OUTPUT_PATH}`. The folder will be created, if
   missing.

 * Environment variable 'EMAIL' can be used to set the email address to which
   the Torque/PBS scheduler will send email reports when the jobs finishes.

 * Chastity filtering prior to alignment of FASTQ files is now optional by
   setting environment variable 'CHASTITY_FILTERING' (default is true).
  
 * Generalized the `run_demo/_run_*` scripts to make it easier to reuse them
   for other samples.

 * Most scripts do now respect the number of cores assigned to it
   ('PBS_NUM_PPN') by the Torque/PBS scheduler.  This makes it easier to
   increase the amount of parallelization used.  It also lowers the risk of
   using more cores by mistake than assigned.

 * That all required input files exist is now asserted as soon as possible and
   in all steps in order to detect (user or coding) mistakes as early as
   possible, which helps troubleshooting.

### SOFTWARE QUALITY

 * TESTS: Add tests/Makefile to simplify testing of all the steps.

 * TESTS: Two in-house tumor-normal data sets are now available for testing the
   pipeline; one complete whole-genome sample ('Patient157') and one
   two-chromosome subset ('Patient157t') of the same sample.  Testing of full
   sample takes ~120+ hours (walltime) and the smaller sample ~20 hours to
   complete. Note, it is necessary to disable chastity filtering when testing
   with the smaller set.

### BUG FIXES

 * If 'PYTHONPATH' was set to include a non Python 2.6.6 version, then various
   Python errors were produced.  Now 'PYTHONPATH' is unset everywhere before
   calling Python.


## Version 2018-09-08

### DOCUMENTATION

 * Add "how-to-run" instructions to README.


### SOFTWARE QUALITY

 * All PBS (\*.pbs) and Bash scripts (scripts/\*.sh) now pass ShellCheck tests.
   Significant changes involve quoting command-line options, adding assertions
   that `cd` and `mkdir` actual works.

 * Add `make check` to check scripts with ShellCheck.

 * The code is now continuously validated using the Travis CI service.


### BUG FIXES

 * Several Bash scripts/\*.sh had `#!/bin/csh` shebangs.
