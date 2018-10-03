# LG3_Pipeline

## Version 2018-09-28-9000 (develop version)

### SIGNIFICANT CHANGES

 * The recalibration steps (Recal and Recall_pass2) now specifies the region
   list when calling GATK's RealignerTargetCreator for creating the intervals
   used for indel detection.  This significantly speeds up these recalibration
   steps, e.g. recalibration of Patient157t (two chromosomes) went down from
   ~14-15 hours to ~6 hours.  In addition, the power to detect mutations
   should improve by specifying regions because we will not waste power in
   testing for mutations outside these regions.  Note that the set of
   mutations identified will change slightly because of this, i.e. although
   the difference should be few, ideally already processed samples should be
   reprocessed.

### NEW FEATURES

 * Now `lg3 test validate` supports also the new Patient157t10 data set.

 * ROBUSTNESS: Now `_run_Recal` and `_run_Recal_pass2`, asserts that `NORMAL`
   is part of the specified `SAMPLES` set.

 * Harmonized the names of the *.out and *.err log files produced by the
   run scripts.

 * `lg3 status` now uses boolean flags instead of options with boolean values.

### BUG FIXES

 * The last run script, `_run_PostMut`, did not acknowledge the environment
   variable `PROJECT` in one of its parts, where it instead used a hardcoded
   `LG3` value.

 * `lg3 test validate` failed if `PROJECT` was not the default value ('LG3').

 * `FilterMutations/filter.profile.sh` added `/home/jocostello/shared/LG3_Pipeline`
   to the `PYTHONPATH` instead of `${LG3_HOME}`.


## Version 2018-09-28

### SIGNIFICANT CHANGES

 * Added `_run_Recal_pass2` for recalibrating merged BAM files.

 * Now the default input folder for trimming and alignment is rawdata/.
   It used to be an absolute path specific to the Costello lab storage.

 * Chastity filtering (prior to alignment of FASTQ files) is now disabled by
   default. To enable, set environment variable `LG3_CHASTITY_FILTERING=true`.

 * The default output folder to which trimmed FASTQ files are written is now
   defined by the `LG3_OUTPUT_ROOT` environment variable (default is output/)
   rather than the folder of the raw FASTQ files.

### NEW FEATURES

 * Add bin/ folder with `lg3` command.  Currently, it implements `lg3 status`
   and `lg3 test`.  `lg3 status` is used for checking of the output on the
   different stages in the pipeline.  `lg3 test setup` is used to set up the
   test example.  `lg3 test validate` is used to validate the results of the
   test example toward a reference currently stored on the TIPCC file system.

 * More scripts now takes environment variable `PROJECT` (defaults to `LG3`)
   as an optional input to control the subfolder of the output data.
 
 * If the optional _run_Recal_pass2 step is run, which occurs after
   recalibration and merging, it will rename the existing exome_recal/$PATIENT/
   subfolder to exome_recal/$PATIENT.before.merge/ such that the final output
   is always in exome_recal/$PATIENT/ regardless of merging or not.

 * Now using extension *.tsv for patient_ID_conversions.tsv (was *.txt) to
   clarify that it is a tab-delimited file.

### DOCUMENTATION

 * README now include instructions on how to check the progress (`lg3 status`)
   and the reproducibility of the test example (`lg3 test setup` and
   `lg3 test validate`).
   
### SOFTWARE QUALITY:

 * HARMONIZATION: Using `PROJECT` everywhere; previously `PROJ` was also used.

### BUG FIXES

 * _run_Align_gz failed to detect already processed samples (due to a typo).
 
 * _run_Align_gz used the wrong default input folder - it looked for the
   trimmed FASTQ files in rawdata/ rather than output/.

 * Scratch folders were not job specific for most TIPCC users.


## Version 2018-09-19

### SIGNIFICANT CHANGES

 * Environment variable `EMAIL` must now be set in order to run any of the
   steps in the pipeline; if not set, an informative error is produced.  Set
   it to the email address where you wish the scheduler to send job reports,
   e.g. `export EMAIL=alice@example.org`.

 * Renamed the optional environment variable `CHASTITY_FILTERING` to
   `LG3_CHASTITY_FILTERING`.

### NEW FEATURES

 * Added run scripts `_run_Merge` and `_run_Merge_QC` for merging recalibrated,
   replicated BAM files that are for the same sample.
 
 * Environment variable `LG3_INPUT_ROOT` is now optional.  If not specified,
   it will be set to a sensible default depending on `LG3_OUTPUT_ROOT`.

 * In order to minimize the risk for clashes, now using user and job specific
   scratch folders - used to only be only user specific.

 * Giving more informative error message in case files are missing.

### DOCUMENTATION

 * Updated README with details on how to run the pipeline on the example test
   data and from any location.

 * Mention `module load CBC lg3` for TIPCC users.
 
### BUG FIXES

 * Run script `_run_Pindel` assumed that resources/ folder was in the working
   directory rather than in the `LG3_HOME` directory.

 * A jobs that was allocated 12 cores by the scheduler would only run 2 cores,
   because the first digits was dropped due to a Bash typo.  This bug was
   introduced in the previous version.
 

## Version 2018-09-17

### SIGNIFICANT CHANGES

 * The pipeline can now be run by any user on the TIPCC compute cluster by
   setting environment variables `LG3_HOME`, `LG3_OUTPUT_ROOT`, and
   `LG3_INPUT_ROOT`. If not set, the default is to use the hardcoded folders
   used in previous versions of the pipeline.

### NEW FEATURES

 * The location of the LG3 Pipeline folder can now set via environment variable
   `LG3_HOME`, e.g. `export LG3_HOME=/path/to/LG3_Pipeline`.
  
 * The location of where result files are written can be set via environment
   variable `LG3_OUTPUT_PATH`.  For example, to output to the folder `output/`
   in the current directory use `export LG3_OUTPUT_PATH=output`. The folder
   will be created, if missing.
  
 * The location of where output files from previous steps in the pipeline is
   located can be set via environment variable `LG3_INPUT_PATH`, which should
   typically be set to the same folder as `LG3_OUTPUT_PATH`, i.e.
   `export LG3_INPUT_PATH=${LG3_OUTPUT_PATH}`. The folder will be created, if
   missing.

 * Environment variable `EMAIL` can be used to set the email address to which
   the Torque/PBS scheduler will send email reports when the jobs finishes.

 * Chastity filtering (prior to alignment of FASTQ files) is now optional by
   setting environment variable `CHASTITY_FILTERING` (default is true).
  
 * Generalized the `run_demo/_run_*` scripts to make it easier to reuse them
   for other samples.

 * Most scripts do now respect the number of cores assigned to it
   (`PBS_NUM_PPN`) by the Torque/PBS scheduler.  This makes it easier to
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

 * If `PYTHONPATH` was set to include a non Python 2.6.6 version, then various
   Python errors were produced.  Now `PYTHONPATH` is unset everywhere before
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
