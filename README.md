# LG3_Pipeline

[![Build Status](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline.svg?branch=develop)](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline)


## What's new?

See [NEWS](NEWS.md) for the changlog.



## Steps to run tests on TIPCC

### 1. Setup

Clone the [LG3_Pipeline] repository, e.g.

```sh
$ cd /path/to/tests/
$ git checkout git@github.com:UCSF-Costello-Lab/LG3_Pipeline.git
$ cd LG3_Pipeline
```

Clone the [LG3_Pipeline] repository, e.g.

### 1 Change directory to the root of the pipeline repository, e.g.

```sh
cd /home/jocostello/shared/LG3_Pipeline
```

### 2 Preparations (do once)

Create the following sets of symbolic links to various directories containing resources, tools, etc.

```sh
ln -s /home/jocostello/shared/LG3_Pipeline_HIDE/resources resources
ln -s /home/jocostello/shared/LG3_Pipeline_HIDE/tools tools
ln -s /home/jocostello/shared/LG3_Pipeline_HIDE/AnnoVar AnnoVar
ln -s /home/jocostello/shared/LG3_Pipeline_HIDE/pykent pykent
ln -s runs_demo/patient_ID_conversions.demo patient_ID_conversions.txt
```

### 3 Trimming FASTQ files (~20 minutes)

``` sh
 cp runs_demo/_run_Trim .
_run_Trim
```

### 4 Aligning FASTQ files to reference genome (~1 hour)

```sh
cp runs_demo/_run_Align_gz .
_run_Align_gz
```

### 5 Recalibration (~13-14 hours)

```sh
cp runs_demo/_run_Recal .
_run_Recal
```

### 6a Pindel (~1.5 hours)

```sh
cp runs_demo/_run_Pindel_157t .
_run_Pindel_157t
```

### 6b Mutation detection (~4 hours)

```sh
cp runs_demo/_run_MutDet .
_run_MutDet
```
   
### 7 Post-mutation summaries (<5 minutes)

```sh
cp runs_demo/_run_PostMut .
_run_PostMut
```

All Done!

Note: All steps should be ran sequentially, except 6a and 6b, which can be ran in parallel.


See [Demo_output.md](run_demo/Demo_output.md) for a summary of what the output looks like.


[LG3_Pipeline]: https://github.com/UCSF-Costello-Lab/LG3_Pipeline
