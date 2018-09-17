# How to test anywhere

## Setup

Clone the [LG3_Pipeline] repository, e.g.

```sh
$ cd /path/to/tests/
$ git checkout git@github.com:UCSF-Costello-Lab/LG3_Pipeline.git
$ cd LG3_Pipeline
```

## Testing

Go to the test directory:
```sh
$ cd /path/to/tests/LG3_Pipeline/tests
```

and then run each of the following steps in order.  You _cannot_ launch the next step until the _jobs_ of the previous step has completed.  The expection are `make step6a` and `make step6b` that can be launched in parallel.

```sh
$ make step3    ## ~20 minutes
$ make step4    ## ~1 hour
$ make step5    ## ~13-14 hours
$ make step6a   ## ~1.5 hours
$ make step6b   ## ~4 hours
$ make step7    ## < 5 minutes
```

The expected set of files produced in each of the above steps are summarized in [Demo_output.md].  The set of identified mutations are available in [Patient157t.R.mutations].



[LG3_Pipeline]: https://github.com/UCSF-Costello-Lab/LG3_Pipeline
[Demo_output.md]: ../runs_demo/Demo_output.md
[Patient157t.R.mutations]: ../runs_demo/Patient157t.R.mutations
