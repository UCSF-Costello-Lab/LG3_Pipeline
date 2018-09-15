# LG3_Pipeline

[![Build Status](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline.svg?branch=develop)](https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline)


## What's new?

See [NEWS](NEWS.md) for the changlog.




## Steps to run test job on TIPCC

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

### 3 Copy _run_Trim_P157 script to the main directory and run it (~4-5h)

``` sh
 cp runs_demo/_run_Trim_P157t .
_run_Trim_P157t
```

### 4 Copy _run_Align_gz_P157t script to the main directory and run it (~10-16h)

```sh
cp runs_demo/_run_Align_gz_P157t .
_run_Align_gz_P157t
```

### 5 Copy _run_Recal_P157t script to the main directory and run it (~85h)

```sh
cp runs_demo/_run_Recal_P157t .
_run_Recal_P157t
```

### 6a Copy _run_Pindel_157t script to the main directory and run it (~4h)

```sh
cp runs_demo/_run_Pindel_157t .
_run_Pindel_157t
```

### 6b Copy _run_MutDet_P157t script to the main directory and run it (~20-21h)

```sh
cp runs_demo/_run_MutDet_P157t .
_run_MutDet_P157t
```
   
### 7 Copy _run_PostMut_P157t script to the main directory and run it (~1h)

```sh
cp runs_demo/_run_PostMut_P157t .
_run_PostMut_P157t
```

All Done!

Note: All steps should be ran sequentially, except 6a and 6b, which can be ran in parallel.


See [Demo_output.md](Demo_output.md) for a summary of what the output looks like.
