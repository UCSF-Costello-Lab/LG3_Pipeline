# LG3_Pipeline

[![Build Status](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline.svg?branch=develop)](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline)

_Warning: Because of hardcoded paths and software dependencies, this software currently only runs on the UCSF [TIPCC] compute cluster.  It is our long-term goal to make it run anywhere._


## What's new?

See [NEWS](NEWS.md) for the changlog.



## Instructions

The LG3 Pipeline is pre-installed on the [TIPCC] cluster.  To get access to it, load the following module:

```sh
$ module load CBC lg3
$ lg3 --version
2018-10-08
```

See `module avail` for alternative versions.


## Run test example

### Setup

To run through the built-in "small" test example (20-25 hours), let's create a separate project folder:
```sh
$ mkdir -p /path/to/lg3-ex
$ cd /path/to/lg3-ex
```

The first thing we want to do is to create an `output/` folder.  If we want it in the same location, we do:
```sh
$ mkdir output   ## folder where the output files will be saved
```
If we want it to be on a separate drive, we can create it there and then using a symbol link, e.g.
```sh
$ mkdir -p /another/drive/lg3-ex/output
$ ln -s /another/drive/lg3-ex/output output
```
In both cases, there will be a local `./output/` folder that the LG3 pipeline can write to.

The remaining parts of the test setup can be either be created automatically using `lg3 test setup` (the `lg3` command is in `${LG3_HOME}/bin`), or manually as one would do when analyzing other data than the test data.  To set up the test automatically, use:

```sh
$ lg3 test setup
*** Setup
[OK] PROJECT: LG3
[OK] PATIENT: Patient157t (required for 'lg3 test validate')
[OK] CONV: patient_ID_conversions.tsv
[OK]   => SAMPLES: Z00599t Z00600t Z00601t (required by '_run_Recal')
[OK]   => NORMAL: 'Z00599t' (required by '_run_Recal')
[OK] EMAIL: alice@example.org
[OK] LG3_HOME: /home/shared/cbc/software_cbc/LG3_Pipeline
[OK] LG3_OUTPUT_ROOT: output
[OK] Patient TSV file: patient_ID_conversions.tsv
[OK] Raw data folder: rawdata
[OK] Run scripts: _run_Align_gz
[OK] Run scripts: _run_Merge
[OK] Run scripts: _run_Merge_QC
[OK] Run scripts: _run_MutDet
[OK] Run scripts: _run_Pindel
[OK] Run scripts: _run_PostMut
[OK] Run scripts: _run_Recal
[OK] Run scripts: _run_Recal_pass2
[OK] Run scripts: _run_Trim
[OK] R packages: 'RColorBrewer'
```

From the above, we should have a directory containing the following files and folders:
```sh
$ tree
.
├── output -> /another/drive/lg3-ex/output
├── patient_ID_conversions.tsv
├── rawdata -> /costellolab/data1/shared/LG3_Pipeline/example_data/rawdata
├── _run_Align_gz
├── _run_Merge
├── _run_Merge_QC
├── _run_MutDet
├── _run_Pindel
├── _run_PostMut
├── _run_Recal
├── _run_Recal_pass2
└── _run_Trim
```


### Running the tests

**Importantly**, before starting, we need to set the `EMAIL` environment variables to an email address where job notifications are sent.
```sh
$ export EMAIL=alice@example.org
```
This can preferably be set in your global `~/.bashrc` script.


Now, we are ready to launch the pipeline (step by step):

``` sh
$ module load CBC lg3
$ cd /path/to/lg3-ex
$ ./_run_Trim                    ## ~20 minutes
$ ./_run_Align_gz                ## ~1 hour
$ ./_run_Recal                   ## ~13-15 hours
$ ./_run_Pindel && ./_run_MutDet ## ~1.5 hours & ~4 hours
$ ./_run_PostMut                 ## ~5 minutes
```

_Note_, all steps should be ran sequentially, except `_run_Pindel` and `_run_MutDet`, which can be ran in parallel (as soon as `_run_Recal` has finished).

Throughout all steps, you can check the current status using the `lg3 status` command.  Here is what the output looks like when all steps are complete:
```sh
$ lg3 status --all Patient157t
hecking output for project LG3
Patient/samples table patient_ID_conversions.tsv
BAM suffix bwa.realigned.rmDups.recal.insert_size_metrics
Patients Patient157t
****** Checking Patient157t Normal: Z00599t
Fastq Z00599t  OK
Fastq Z00600t  OK
Fastq Z00601t  OK
Trim Z00599t  OK
Trim Z00600t  OK
Trim Z00601t  OK
BWA Z00599t  OK
BWA Z00600t  OK
BWA Z00601t  OK
Recal Z00599t  OK
Recal Z00600t  OK
Recal Z00601t  OK
UG  OK 7579
Germline Z00600t  OK
Germline Z00601t  OK
Pindel  OK 3
Mutect Z00600t  OK 28
Mutect Z00601t  OK 53
MutCombine  OK 16
MAF  OK
LOH plots  OK
```

Done!  All results are written to the `./output/` folder in different subdirectories.


See [Demo_output.md](run_demo/Demo_output.md) for a summary of what the output looks like.  Particularly, the text file `./output/LG3/MutInDel/Patient157t.R.mutations` contain the identified multations.



### Validate test results

To validate that you get the expected results when running through the tests, call `lg3 test validate`.  Here is an example of the output when all steps are completed:

```
$ lg3 test validate Patient157t
*** Configuration
[OK] CONV=patient_ID_conversions.tsv
[OK] LG3_TEST_TRUTH=/costellolab/data1/shared/LG3_Pipeline/example_data

*** Trimming of FASTQ Files
[OK] file tree ('output/LG3/trim/Z00*-trim')
[OK] file sizes ('output/LG3/trim/Z00*-trim/*')

*** BWA Alignment of FASTQ Files
[OK] file tree ('output/LG3/exomes')
[OK] file sizes ('output/LG3/exomes/Z00*/*')

*** Recalibration of BAM Files
[OK] file tree ('output/LG3/exomes_recal/Patient157t')
[OK] file sizes ('output/LG3/exomes_recal/Patient157t/*')
[OK] file sizes ('output/LG3/exomes_recal/Patient157t/germline/*')
[OK] file sizes ('output/LG3/exomes_recal/Patient157t/*.bai')

*** Pindel Processing
[OK] file tree ('output/LG3/pindel')
[OK] file rows ('output/LG3/pindel/Patient157t.pindel.cfg')
[OK] file sizes ('output/LG3/pindel/Patient157t_pindel/*')

*** MutDet Processing
[OK] file tree ('output/LG3/mutations/Patient157t_mutect')
[OK] file sizes ('output/LG3/mutations/Patient157t_mutect/*')

*** Post-MutDet Processing
[OK] file tree ('output/LG3/MAF')
[OK] file sizes ('output/LG3/MAF/Patient157t_MAF/*')
[OK] file sizes ('output/LG3/MAF/Patient157t_plots/*')
[OK] file tree ('output/LG3/MutInDel')
[OK] file sizes ('output/LG3/MutInDel/*')
[OK] file content ('output/LG3/MutInDel/Patient157t.R.mutations')
```

_Comment:_ There might minor discrepancies, which is due to these tests of file sizes sometimes being slightly to strict.  Regardless, if you get all `OK` for the content of `output/LG3/MutInDel/Patient157t.R.mutations`, which contains the set of identified mutations, then you reproduced the expected results.



## Appendix

### Installation notes

The pipeline is installed on the TIPCC cluster, by cloning the [LG3_Pipeline] git repository and running the setup once, i.e.

```sh
$ cd /path/to/
$ git clone https://github.com/UCSF-Costello-Lab/LG3_Pipeline.git
$ cd LG3_Pipeline
$ make setup
```

The above folder is now where the LG3 Pipeline lives.  Environment variable `LG3_HOME` is set to point to this folder, e.g.

```sh
export LG3_HOME=/path/to/LG3_Pipeline
```


[LG3_Pipeline]: https://github.com/UCSF-Costello-Lab/LG3_Pipeline
[TIPCC]: https://ucsf-ti.github.io/tipcc-web/
[RColorBrewer]: https://cran.r-project.org/package=RColorBrewer
