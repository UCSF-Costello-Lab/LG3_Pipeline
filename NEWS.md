# LG3_Pipeline

## Version 2021-10-11

## BUG FIXES

 * `./lg3.conf` would not found shell scripts if the working
   directory was changed before calling the script.  This would
   happen with for instance `lg3 run PostMut`.

 * `lg3 run MutDet` broke in version 2021-10-10 because the internal
   `assert_*()` functions overwrote global variables. Now all
   internal Bash functions declare local variables explicitly.


## Version 2021-10-10

### SIGNFICANT CHANGES

 * Add `lg3 run <step>` command for launching the different LG3
   steps, e.g. `lg3 run Trim` and `lg3 run Align_gz`.

 * All software dependencies are now obtained from the CBI software
   stack available via `module load CBI`.

 * `lg3 test setup` no longer create symbolic links to run scripts,
   because we can now use `lg3 run <step>` instead.

### NEW FEATURES

 * Assert errors on software tools are now much more informative,
   e.g. the error message includes also the name of the environment
   variable that specifies the tool.

### BUG FIXES

 * User's ~/.Rprofile could wreak havoc during `lg3 run Recal` when
   calling Picard's CollectMultipleMetrics.jar, which calls `Rscript`.
   We're now using `R_PROFILE_USER=NULL` when calling this substep
   to emulate `Rscript --no-init-file`.


## Version 2021-10-09

### SIGNFICANT CHANGES

 * This is the first release that we managed to run on both TIPCC
   and C4.

### NEW FEATURES

 * Now the internal `LG3_SCRATCH_ROOT` path is agile to type of
   scheduler, i.e. Torque/PBS or Slurm.

 * Adding `-l walltime=hh:mm:ss` and `-l mem=<size>gb` declarations
   to PBS scripts to handle schedulers with hard resource limits.

 * Now `qsub` calls are agile to whether the underlying scheduler
   supports command-line option `-d <path>` or not.

### BUG FIXES

 * User's ~/.Rprofile could wreak havoc for some R scripts, e.g. by
   outputting messages.  Now all Rscript calls use '--vanilla' to make
   sure to run in an vanilla R session without user-specific settings.

 * Python script 'scripts/combine_snvs.py' used a hard-coded path
   to the 'Rscript' executable.

 * One Python script and one Rscript used a hard-coded path to
   bedtools executables.

 * lg3-test used a hardcoded path for the 'Rscript' executable.


## Version 2021-10-08

### NEW FEATURES

 * Now `pindel_all.pbs` reports also on the `ANNOVAR_HOME` software.

 * Now all `runs_demo/run_*` scripts pass also environment variables
   specifying software tools to the submitted job scripts.  This makes it
   possible to override the default software tools.

 * Now it's possible to override the _internal_ environment variables that
   the LG3 pipeline uses, e.g. `export MUTECT=/path/to/muTect-99.jar`.
   Note that this should only be used for troubleshooting and development.

### BUG FIXES

 * Internal assertions incorrectly required that the GATK and the MUTECT JAR
   files should be executable, but that is not required.


## Version 2020-05-26

### NEW FEATURES

 * `lg3 test validate` now compares the MD5 checksums of the content of the
   trimmed FASTQ files, the BWA aligned BAM files and the corresponding BAM
   index files. This requires that MD5 checksum files can be written.

### SOFTWARE QUALITY

 * The 'java', 'python' and 'Rscript' executables are now set in a central
   location to guarantee that the same, expected versions are used everywhere.

 * The AnnoVar, bedtools, cutadapt, BWA, GATK, MuTect, Picard, and Samtools
   executables are now set in a central location to guarantee that the same,
   expected versions are used everywhere.


## Version 2020-05-16

### NEW FEATURES

 * The LG3 Pipeline requires Python 2.  If an incompatible Python version is
   detected on the 'PATH', then an informative error is produced.
   
### KNOWN ISSUES

 * The 'lg3.conf' file must not be edited while the pipeline is running.  If
   done, then the outcome and the results are unpredictable.  This is because
   the 'lg3.conf' file is not frozen when the pipeline is launched.


## Version 2019-07-22

### SIGNIFICANT CHANGES

 * The LG3 Pipeline now refuses to run from within its installation folder,
   i.e. when the current working directory equals '${LG3_HOME}'.  This
   protects against various potential mistakes such as overriding installed
   files and settings.

 
### NEW FEATURES

 * Globals settings for the LG3 Pipeline such as locations of software tools
   are now configured in the '${LG3_HOME}/lg3.conf' bash script (which should
   not be edited by the user).  If a file 'lg3.conf' exists in the current
   working directory ("the project folder"), then that file is sourced after
   '${LG3_HOME}/lg3.conf', which makes it possible to override some or all
   of the predefined global settings on a project to project basis.  The
   latter file can also be used to configure variables such as PATIENT etc.

 * Now 'lg3 status' defaults to using '--all'.

 * ROBUSTNESS: Now `bin/lg3-test` explicitly asserts that Rscript exists
   before attemption to use it.


## Version 2019-03-23

### NEW FEATURES

 * Added option to use new Pindel 0.2.5b8 instead of Pindel 0.2.4t.

 * Added '_run_Align_mem' for an alternative data pre-processing compliant
   with Best Practices 2019.

 * Added '_run_Mutect2' for somatic mutation calling by Mutect2 and GATK 4.1.

 * Added '_run_Align_gz_no_trim' to align without trimming FASTQ data.

 * Added '_run_PSCN' for running the PSCN pipeline directly within the LG3
   pipeline.

### SOFTWARE QUALITY

 * Paths to resources and some other parameters are now in config file
   'lg3.conf' (work in progress).
 

## Version 2018-12-27

### NEW FEATURES

 * More informative and consistent error messages are provided in more place by
   making more use of internal utility functions such as 'error', 'warn',
   'assert_file_exists', 'assert_directory_exists', 'make_dir' and 'change_dir'.
  
### BUG FIXES

 * Recall_pass2.pbs failed to create symbolic link(s).


## Version 2018-12-20

### NEW FEATURES 

 * exomeQualityPlots pipeline is now integrated with the main pipeline.

 * Added stand-alone Germline analysis, exactly the same as in the Recal
   step, which can be used in case the Recal-Germline step fails.

### BUG FIXES

 * Fixed a wrong file extension in Recal_pass2.sh.


## Version 2018-11-12

### NEW FEATURES

 * Errors produced by the pipeline itself do now also output traceback
   information showing the function, line number, and script pathname
   call stack.

### SOFTWARE QUALITY

 * Using more informative names on variables used for script filenames.

 * Earlier detection of errors by asserting that expected output files are
   produced after each internal call of the pipeline finishes.

### BUG FIXES

 * All scripts are now cleaning scratch space in the end of the run.


## Version 2018-10-27

### NEW FEATURES

 * Now `./_run_MutDet` reports on the `NORMAL`, `TUMOR`, and `TYPE` inferred
   from the `CONV` file and the `PATIENT` name, and asserts that such
   entries actually exist in the `CONV` file.

### KNOWN ISSUES

 * It appears not to be possible to quote `INPUT` filenames for Picard, i.e.
   we cannot use `INPUT="<file>"` but have to stick with `INPUT=<file>`.
   This means that those input file names must not have spaces.  GATK has
   the same limitation on its `-I <file>` option.

### BUG FIXES

 * The (optional) `_run_Merge` step would produce error: "scripts/Merge.sh:
   line 6: PROJECT: parameter null or not set".

 * Run scripts `_run_MutDet`, `_run_Merge`, and `_run_Merge_QC` would fail
   if previous step used a `PROJECT` other than the default 'LG3'.

 * Pipeline would not support tab-delimited patient files with Microsoft
   Windows-style line endings, i.e. CRLF (`\r\n`) line endings.

 * `scripts/chk_mutdet.sh` did not acknowledge environment variable 'CONV'.


## Version 2018-10-17

### SIGNIFICANT CHANGES

 * Environment variable `LG3_HOME` must now be set.  If not set, an error
   is produced.  It used to default to a Costello Lab specific location on
   the TIPCC cluster.
 
### NEW FEATURES

 * Alignment jobs now require less memory by default (64 GiB RAM instead of
   100 GiB), which should decreased the average default queuing time.

 * Added `lg3 envir` for displaying current environment variables related
   to the LG3 Pipeline.
  
 * Added `lg3 --news` for displaying the NEWS.md file in the terminal.

### KNOWN ISSUES

 * Patient IDs must not contain underscores (`_`) because the Pindel step
   of the pipeline does not support that.  All steps of the pipeline now
   assert that patient IDs do no contain underscores.

### BUG FIXES

 * PBS scripts would only run on TIPCC compute nodes that support the legacy
   PBS `bigmem` flag.  By removing this unnecessary `bigmem` requirement from
   all PBS scripts, jobs can now run on all compute nodes that meet the core
   and memory requirement specified by each PBS script (or is overridden in
   the LG3 call).


## Version 2018-10-11

### SIGNIFICANT CHANGES

 * Run scripts now infer `SAMPLES` and `NORMAL` from the patient file (`CONV`)
   given the `PATIENT` name.  It is no longer necessary to set environment
   variables `SAMPLES` and `NORMAL` when running the pipeline. These variables
   will become deprecated soon and later produce an error if specified.

### DOCUMENTATION

 * Add section on 'Contributors' to the README.

### SOFTWARE QUALITY

 * HARMONIZATION: Standardizing variable names throughout all scripts.

 * TESTS: Tests now defaults to using Patient157t10.
 
 * TESTS: Added test set 'Patient157_t10_underscore' (sic!) containing FASTQ
   files with additional underscores and `_R1`/_R2` suffixes in their names.
   This test set is just a renamed copy of the existing 'Patient157t10' set.

### BUG FIXES

 * The pipeline did not support FASTQ file names with underscores (`_`) other
   than the once indicating paired end reads `_R1` and `_R2`.  File names
   with a suffix between `_R1`/`_R2` and `.fastq.gz` were also not supported.
   Note that trimming drops any `_R1/_R2` suffixes, e.g. trimming a FASTQ
   file `Z00600_t10_AATCCGTC_L007_R1_001_HQ_paired.fastq.gz` produces a
   trimmed FASTQ file `Z00601_t10_AATCCGTC_L007-trim_R1.fastq.gz`.

 * Some run scripts (`_run_MutDet`), job scripts (`Recal_bigmem.pbs`,
  `MutDet_TvsN.pbs`, and `UG.pbs`), and scripts (`scripts/chk_mutdet.sh` and
  `scripts/chk_pindel.sh`) did not catch errors and quit with exit code 1.

 * `lg3 test setup` incorrectly reported that the CONV file does not exist.
 

## Version 2018-10-08

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

 * The default output folder is now 'output/' in the current working directory.
   It used to be a folder specific to the Costello Lab, which could be
   overridden by setting `LG3_OUTPUT_ROOT`.  There is no longer a need to set
   this environment variable, which soon will be deprecated together with the
   LG3_INPUT_ROOT environment variable.

### NEW FEATURES

 * Now 'lg3 test setup' also installs required R packages, if missing.
 
 * Now `lg3 test validate` supports also the new Patient157t10 data set.

 * ROBUSTNESS: Now `_run_Recal` and `_run_Recal_pass2`, asserts that `NORMAL`
   is part of the specified `SAMPLES` set.

 * Harmonized the names of the *.out and *.err log files produced by the
   run scripts.

 * `lg3 status` now uses boolean flags instead of options with boolean values.

 * Scripts now report on the hostname to help any troubleshooting.

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
