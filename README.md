[![checks](https://github.com/UCSF-Costello-Lab/LG3_Pipeline/actions/workflows/checks.yml/badge.svg)](https://github.com/UCSF-Costello-Lab/LG3_Pipeline/actions/workflows/checks.yml)

# LG3_Pipeline

_Warning: Because of hardcoded paths to annotation data files, and software dependencies on the [CBI software stack](https://www.c4.ucsf.edu/software/software-repositories.html), this software tool runs only on the UCSF [TIPCC] and [C4] compute clusters.  It is our long-term goal to make it run anywhere._


## What's new?

See [NEWS](NEWS.md) for the changlog.



## Instructions

The LG3 Pipeline is pre-installed on the [TIPCC] and the [C4] clusters.  To get access to it, load the following module:

```sh
$ module load CBI lg3
$ lg3 --version
2021-10-09
```

See `module avail` for alternative versions.


## Run test example

### Setup

To run through the built-in "small" test example (5-10 hours), let's create a separate project folder:
```sh
$ mkdir -p ~/lg3-demo
$ cd ~/lg3-demo
```

The first thing we want to do is to create an `output/` folder.  If we want it in the same location, we do:
```sh
$ mkdir output   ## folder where the output files will be saved
```
If we want it to be on a separate drive, we can create it there and then using a symbol link, e.g.
```sh
$ mkdir -p /another/drive/lg3-demo/output
$ ln -s /another/drive/lg3-demo/output output
```
In both cases, there will be a local `./output/` folder that the LG3 pipeline can write to.

The remaining parts of the test setup can be either be created automatically using `lg3 test setup` (the `lg3` command is in `${LG3_HOME}/bin`), or manually as one would do when analyzing other data than the test data.  To set up the test automatically, use:

```sh
$ export PATIENT=Patient157t10
$ lg3 test setup
Sourced: /path/to/LG3_Pipeline/lg3.conf
*** Setup
[OK] LG3_HOME: /path/to/LG3_Pipeline
[OK] R packages: 'RColorBrewer'
[OK] EMAIL: alice@example.org
[OK] PROJECT: LG3
[OK] PATIENT: Patient157t10 (required for 'lg3 test validate')
[OK] CONV (patient TSV file): patient_ID_conversions.tsv
[OK]   => SAMPLES: Z00599t10 Z00600t10 Z00601t10  (required by 'Recal' step)
[OK]   => NORMAL: 'Z00599t10' (required by 'Recal' step)
[OK] Raw data folder: rawdata
[OK] LG3_OUTPUT_ROOT: output
```

From the above, we should have a directory containing the following files and folders:
```sh
$ tree
.
|-- output
|-- patient_ID_conversions.tsv -> ~/lg3-demo/runs_demo/patient_ID_conversions.tsv
`-- rawdata -> /costellolab/data1/shared/LG3_Pipeline/example_data/rawdata

2 directories, 19 files
```


### Running the tests

**Importantly**, before starting, we need to set the `EMAIL` environment variables to an email address where job notifications are sent.
```sh
$ export EMAIL=alice@example.org
```
This can preferably be set in your global `~/.bashrc` script.


Now, we are ready to launch the pipeline (step by step):

``` sh
$ cd ~/lg3-demo
$ module load CBI lg3
$ export PATIENT=Patient157t10
$ lg3 run Trim                      ## ~5 minutes
$ lg3 run Align_gz                  ## ~5-10 minutes
$ lg3 run Recal                     ## ~2.5 hours
$ lg3 run Pindel && lg3 run MutDet  ## ~20 minutes & ~1.0 hour
$ lg3 run PostMut                   ## ~5 minutes
```

Optionally we can run the [exomeQualityPlots](https://github.com/SRHilz/exomeQualityPlots) pipeline developed by Stephanie Hilz (UCSF).
The pipeline generates quality plots of exome libraries and quality stats for mutation calling.
First we need to clone original exomeQualityPlots pipeline somewhere, e.g.
``` sh
$ mkdir -p ~/pipelines/exomeQualityPlots 
$ cd ~/pipelines/exomeQualityPlots 
$ git clone git@github.com:SRHilz/exomeQualityPlots.git
$ cd ${LG3_HOME}
$ ln -s ~/pipelines/exomeQualityPlots exomeQualityPlots
```

Now we are ready to roll:
``` sh
$ lg3 run QC_1 && lg3 run QC_2
$ lg3 run QC_3
```

Another option is to run [Costello-PSCN-Seq](https://github.com/HenrikBengtsson/Costello-PSCN-Seq) pipeline created by Henrik Bengtsson. The pipline implements Parent-specific copy number (PSCN) analysis on paired tumor-normal samples.
First we need to clone Costello-PSCN-Seq pipeline somewhere, e.g.
``` sh
$ mkdir -p ~/pipelines/Costello-PSCN-Seq
$ cd ~/pipelines/Costello-PSCN-Seq
$ git clone git@github.com:HenrikBengtsson/Costello-PSCN-Seq.git
$ cd ${LG3_HOME}
$ ln -s ~/pipelines/Costello-PSCN-Seq Costello-PSCN-Seq
```

Now we are ready to run:
``` sh
$ lg3 run PSCN
```

_Note_, all steps should be ran sequentially, except steps `Pindel` and `MutDet`, which can be run in parallel (as soon as the `Recal` step has finished).

_Tip:_ Each step of the pipeline is submitted to the Torque/PBS scheduler requesting a default number of cores (`nodes=1:ppn=...`) and amount of memory (`vmem=...`).  For now, you need to follow the source code to see what these defaults are.  You can override the defaults via environment variable `QSUB_OPTS`, e.g.
```sh
QSUB_OPTS="-l nodes=1:ppn=6 -l vmem=32gb" lg3 run Align_gz
```


### Checking progress and status

Throughout all steps, you can check the current status using the `lg3 status` command.  Here is what the output looks like when all steps are complete:
```sh
$ export PATIENT=Patient157t10
$ lg3 status
Sourced: /path/to/LG3_Pipeline/lg3.conf
Checking output for project LG3
Patient/samples table patient_ID_conversions.tsv
BAM suffix bwa.realigned.rmDups.recal.insert_size_metrics
Patients Patient157t10
****** Checking Patient157t10 Normal: Z00599t10
Fastq Z00599t10  OK
Fastq Z00600t10  OK
Fastq Z00601t10  OK
Trim Z00599t10  OK
Trim Z00600t10  OK
Trim Z00601t10  OK
BWA Z00599t10  OK
BWA Z00600t10  OK
BWA Z00601t10  OK
Recal Z00599t10  OK
Recal Z00600t10  OK
Recal Z00601t10  OK
UG  OK 7262
Germline Z00600t10  OK
Germline Z00601t10  OK
Pindel  OK 0
Mutect Z00600t10  OK 24
Mutect Z00601t10  OK 29
MutCombine  OK 6
MAF  OK
LOH plots  OK
```

Done!  All results are written to the `./output/` folder in different subdirectories.


See [Demo_output.md](run_demo/Demo_output.md) for a summary of what the output looks like.  Particularly, the text file `./output/LG3/MutInDel/Patient157t10.R.mutations` contain the identified mutations.



### Validate test results

To validate that you get the expected results when running through the tests, call `lg3 test validate`.  Here is an example of the output when all steps are completed:

```
$ export PATIENT=Patient157t10
$ lg3 test validate $PATIENT
Sourced: /path/to/LG3_Pipeline/lg3.conf
*** Configuration
[OK] PROJECT=LG3
[OK] PATIENT=Patient157-t10-underscore
[OK] CONV=patient_ID_conversions.tsv
[OK] LG3_TEST_TRUTH=/costellolab/data1/shared/LG3_Pipeline/example_data

*** Trimming of FASTQ Files
[OK] file tree ('output/LG3/trim/Z00*-trim')
[OK] file sizes ('output/LG3/trim/Z00*-trim/*')

*** BWA Alignment of FASTQ Files
[OK] file tree ('output/LG3/exomes')
[OK] file sizes ('output/LG3/exomes/Z00*/*')

*** Recalibration of BAM Files
[WARN] unexpected file tree ('/costellolab/data1/shared/LG3_Pipeline/example_data/Patient157-t10-underscore/output/LG3/exomes_recal/Patient157-t10-underscore' != 'output/LG3/exomes_recal/Patient157-t10-underscore')
@@ -2 +2,39 @@
-└── germline
+├── germline
+│   ├── NOR-Z00599_t10_AATCCGTC_L007_vs_Z00600_t10_AATCCGTC_L007.germline
+│   ├── NOR-Z00599_t10_AATCCGTC_L007_vs_Z00601_t10_AATCCGTC_L007.germline
+2.1M   output/LG3/exomes_recal/Patient157-t10-underscore/germline
+8.8K   output/LG3/exomes_recal/Patient157-t10-underscore/Z00599_t10_AATCCGTC_L007.bwa.realigned.rmDups.recal.insert_size_metrics
+1.8K   output/LG3/exomes_recal/Patient157-t10-underscore/Z00600_t10_AATCCGTC_L007.bwa.realigned.rmDups.recal.hybrid_selection_metrics
+12K    output/LG3/exomes_recal/Patient157-t10-underscore/Z00600_t10_AATCCGTC_L007.bwa.realigned.rmDups.recal.insert_size_histogram.pdf
+8.4K   output/LG3/exomes_recal/Patient157-t10-underscore/Z00600_t10_AATCCGTC_L007.bwa.realigned.rmDups.recal.insert_size_metrics

*** Recalibration of BAM Files
[OK] file tree ('output/LG3/exomes_recal/Patient157t10')
[OK] file sizes ('output/LG3/exomes_recal/Patient157t10/*')
[OK] file sizes ('output/LG3/exomes_recal/Patient157t10/germline/*')
[OK] file sizes ('output/LG3/exomes_recal/Patient157t10/*.bai')

*** Pindel Processing
[OK] file tree ('output/LG3/pindel')
[OK] file rows ('output/LG3/pindel/Patient157t10.pindel.cfg')
[OK] file sizes ('output/LG3/pindel/Patient157t10_pindel/*')

*** MutDet Processing
[OK] file tree ('output/LG3/mutations/Patient157t10_mutect')
[OK] file sizes ('output/LG3/mutations/Patient157t10_mutect/*')

*** Post-MutDet Processing
[OK] file tree ('output/LG3/MAF')
[OK] file sizes ('output/LG3/MAF/Patient157t10_MAF/*')
[OK] file sizes ('output/LG3/MAF/Patient157t10_plots/*')
[OK] file tree ('output/LG3/MutInDel')
[OK] file sizes ('output/LG3/MutInDel/*')
[OK] file content ('output/LG3/MutInDel/Patient157t10.R.mutations')
```

_Comment:_ There might minor discrepancies, which is due to these tests of file sizes sometimes being slightly to strict.  Regardless, if you get all `OK` for the content of `output/LG3/MutInDel/Patient157t10.R.mutations`, which contains the set of identified mutations, then you reproduced the expected results.



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

Then, in order to get access to the `lg3` command-line tool, make sure to also set:

```sh
export PATH="${LG3_HOME}/bin:${PATH}"
```


### Contributors

The following people (in reverse chronological order) have contributed to the LG3 Pipeline code base over the years:

* Henrik Bengtsson (2015-)
* Ivan Smirnov (2014-)
* Tali Mazor (2012-2017)
* Brett Johnson (2012-2014)
* Barry Taylor (2012-2013)
* Jun Song (2010-2011)


[LG3_Pipeline]: https://github.com/UCSF-Costello-Lab/LG3_Pipeline
[C4]: https://www.c4.ucsf.edu/
[TIPCC]: https://ucsf-ti.github.io/tipcc-web/
