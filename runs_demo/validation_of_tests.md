# Validation of test example

The reference results to compare to:
```sh
truth=/costellolab/data1/shared/LG3_Pipeline/example_data/truth
```

## Existence of folders and files

The following output should be empty (because all files should exist):

```sh
path=output
diff -u <(cd ${truth}; tree ${path}) -u <(tree ${path})
```

## _run_Trim

The following output should be empty (because all files should be of identical sizes):
```sh
path=output
diff -u <(cd ${truth}; tree ${path}/Z00*t-trim) -u <(tree ${path}/Z00*t-trim)
diff -u <(cd ${truth}; du -b ${path}/Z00*t-trim/*) -u <(du -b ${path}/Z00*t-trim/*)
```

## _run_Align_gz

The following output should be empty (because all files should be of identical sizes):
```sh
path=output/LG3/exomes
diff -u <(cd ${truth}; tree ${path}) -u <(tree ${path})
diff -u <(cd ${truth}; du -b ${path}/Z00*t/*) <(du -b ${path}/Z00*t/*)
``` 


## _run_Recal

The following output should be empty (because all files should be of the same "human-readable" size and BAI files of identical size):
```sh
path=output/LG3/exomes_recal
diff -u <(cd ${truth}; tree ${path}) <(tree ${path})
diff -u <(cd ${truth}; du -h ${path}/Patient*t/*) <(du -h ${path}/Patient*t/*)
diff -u <(cd ${truth}; du -h ${path}/Patient*t/germline/*) <(du -h ${path}/Patient*t/germline/*)
diff -u <(cd ${truth}; du -b ${path}/Patient*t/*.bai) <(du -b ${path}/Patient*t/*.bai)
```


## _run_Pindel

The following output should be empty (because all files should be of the same "human-readable" size):

```sh
path=output/LG3/pindel
diff -u <(cd ${truth}; tree ${path}) <(tree ${path})
diff -u <(cd ${truth}; wc -l ${path}/Patient*t.pindel.cfg) <(wc -l ${path}/Patient*t.pindel.cfg)
diff -u <(cd ${truth}; du -h ${path}/Patient*t_pindel/*) <(du -h ${path}/Patient*t_pindel/*)
```
 
## _run_MutDet

The following output should be empty (because all files should be of the same "human-readable" size):

```sh
path=output/LG3/mutations
diff -u <(cd ${truth}; tree -I '*.bed' ${path}) <(tree -I '*.bed' ${path})
diff -u <(cd ${truth}; du -h ${path}/Patient*t_mutect/* | grep -vF .bed) <(du -h ${path}/Patient*t_mutect/*)
```

When `_run_PostMut_`, which produce BED files, has been completed, we can do a full comparison:
```sh
diff -u <(cd ${truth}; tree ${path}) <(tree ${path})
diff -u <(cd ${truth}; du -h ${path}/Patient*t_mutect/*) <(du -h ${path}/Patient*t_mutect/*)
```

Comment: There could be a minor difference in WIG content:
```diff
for ff in ${path}/Patient*t_*/*.wig; do diff -U 0 ${truth}/${ff} ${ff}; done
--- /cbc/henrik/LG3_Pipeline/tests/Patient157t-truth-20180914/output/LG3/mutations/Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.snvs.coverage.mutect.wig      2018-09-15 14:09:40.391889978 -0700
+++ output/LG3/mutations/Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.snvs.coverage.mutect.wig   2018-09-18 15:34:03.471534304 -0700
@@ -12590739 +12590739 @@
-0
+1
```

## _run_PostMut

The following output should be empty (because all files should be of the same "human-readable" size):

```sh
path=output/LG3/MAF
diff -u <(cd ${truth}; tree ${path}) <(tree ${path})
diff -u <(cd ${truth}; du -h ${path}/Patient*t_*/*) <(du -h ${path}/Patient*t_*/*)
```
and
```sh
path=output/LG3/MutInDel
diff -u <(cd ${truth}; tree ${path}) <(tree ${path})
diff -u <(cd ${truth}; du -h ${path}/*) <(du -h ${path}/*)
diff -u ${truth}/${path}/Patient*t.R.mutations ${path}/Patient*t.R.mutations
```
