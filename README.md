# LG3_Pipeline

[![Build Status](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline.svg?branch=develop)](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline)


_Warning: Because of hardcoded paths and software dependencies, this software currently only runs on the UCSF [TIPCC] compute cluster!_


## What's new?

See [NEWS](NEWS.md) for the changlog.


## TIPCC users do not have to install

The LG3 Pipeline is pre-installed on the [TIPCC] cluster.  To get access to it, load the following module:

```sh
$ module load CBC lg3
```

See `module avail` for available versions.


## Installation

Clone the [LG3_Pipeline] repository and run the setup once, e.g.

```sh
$ cd /path/to/
$ git clone https://github.com/UCSF-Costello-Lab/LG3_Pipeline.git
$ cd LG3_Pipeline
$ make setup
```

The above folder is now where the LG3 Pipeline lives.  Set environment `LG3_HOME` to point to this location, e.g.

```sh
export LG3_HOME=/path/to/LG3_Pipeline
```


## Run test example

### Setup

To run through the built-in "small" test example (20-25 hours), let's create a separate project folder:
```sh
$ mkdir -p /path/to/lg3-test
$ cd /path/to/lg3-test
```

The first thing we want to do is to create an `output/` folder.  If we want it in the same location, we do:
```sh
$ mkdir output   ## folder where the output files will be saved
```
If we want it to be on a separate drive, we can create it there and then using a symbol link, e.g.
```sh
$ mkdir -p /another/drive/lg3-test/output
$ ln -s /another/drive/lg3-test/output output
```
In both cases, there will be a local `./output/` folder that the LG3 pipeline can write to.

Next we want to create a `rawdata/` folder where the pipeline looks for the raw input data.  As above, we can either create it and copy our files over or we can point a symbolic link to an existing folder elsewhere on the file system.  For the test example, we will use:
```sh
$ ln -s /costellolab/data1/ismirnov/tmp rawdata
```

We also need a sample annotation file.  For the test example, we reuse the following:
```sh
$ cp ${LG3_HOME}/runs_demo/patient_ID_conversions.demo patient_ID_conversions.txt
```

Finally, we need to create a set up "run scripts".  For the test example, we can copy the built-in ones:
```sh
$ cp ${LG3_HOME}/runs_demo/_run_* .
```

From the above, we should have a directory containing the following files and folders:
```sh
$ tree
.
├── output -> /another/drive/lg3-test/output
├── patient_ID_conversions.txt
├── rawdata -> /costellolab/data1/ismirnov/tmp
├── _run_Align_gz
├── _run_Merge
├── _run_Merge_QC
├── _run_MutDet
├── _run_Pindel
├── _run_PostMut
├── _run_Recal
└── _run_Trim
```


### Running the tests

**Importantly**, before starting, we need to set the following environment variables:
```sh
export EMAIL=first.last@example.org     ## scheduler sent notifications here!
export LG3_HOME=/path/to/LG3_Pipeline
export LG3_OUTPUT_ROOT=output
```
These can all be set in your global `~/.bashrc` script or equivalently.

If you're on the TIPCC cluster and loaded the lg3 module;
```sh
$ module load CBC lg3
```
then all you need to set is the `EMAIL` environment variable.


_Oh, one more thing_:  We need to install the RColorBrewer packages in order for the `_run_PostMut` step to work, and we need it to be installed for the legacy version of R that is currently used by the pipeline.  To install this, do:

```sh
$ /opt/R/R-latest/bin/R   ## the version of R used by the pipeline!
[...]
> if (!require("RColorBrewer")) install.packages("RColorBrewer", repos = "http://cloud.r-project.org")
[...]
> quit("no")
$
```


Now, we are ready to launch the pipeline (step by step):

``` sh
$ cd /path/to/lg3-test
$ ./_run_Trim                    ## ~20 minutes
$ ./_run_Align_gz                ## ~1 hour
$ ./_run_Recal                   ## ~13-15 hours
$ ./_run_Pindel && ./_run_MutDet ## ~1.5 hours & ~4 hours
$ ./_run_PostMut                 ## ~5 minutes
```

_Note_, all steps should be ran sequentially, except `_run_Pindel` and `_run_MutDet`, which can be ran in parallel (as soon as `_run_Recal` has finished).

Done!  All results are written to the `./output/` folder in different subdirectories.

See [Demo_output.md](run_demo/Demo_output.md) for a summary of what the output looks like.  Particularly, the text file `./output/LG3/MutInDel/Patient157t.R.mutations` contain the identified multations.


[LG3_Pipeline]: https://github.com/UCSF-Costello-Lab/LG3_Pipeline
[TIPCC]: https://ucsf-ti.github.io/tipcc-web/