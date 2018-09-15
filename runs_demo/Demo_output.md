### Dataset for demo/test run contains one normal and two tumor samples, truncated to chr17+chr19

### Input files for demo/test run

```
du -b Z00???t_R?.fastq.gz
484859627	Z00599t_R1.fastq.gz
510807204	Z00599t_R2.fastq.gz
484114380	Z00600t_R1.fastq.gz
500782232	Z00600t_R2.fastq.gz
449535962	Z00601t_R1.fastq.gz
470376323	Z00601t_R2.fastq.gz
```

### Expected output files and sizes for demo/test run

#### Step _run_trim_P157t

```
du -b Z00???t-trim/*
484267842	Z00599t-trim/Z00599t-trim_R1.fastq.gz
1726	Z00599t-trim/Z00599t-trim_R1.trimming_report.txt
510113529	Z00599t-trim/Z00599t-trim_R2.fastq.gz
1936	Z00599t-trim/Z00599t-trim_R2.trimming_report.txt
483507116	Z00600t-trim/Z00600t-trim_R1.fastq.gz
1726	Z00600t-trim/Z00600t-trim_R1.trimming_report.txt
500096024	Z00600t-trim/Z00600t-trim_R2.fastq.gz
1936	Z00600t-trim/Z00600t-trim_R2.trimming_report.txt
448957214	Z00601t-trim/Z00601t-trim_R1.fastq.gz
1726	Z00601t-trim/Z00601t-trim_R1.trimming_report.txt
469699788	Z00601t-trim/Z00601t-trim_R2.fastq.gz
1927	Z00601t-trim/Z00601t-trim_R2.trimming_report.txt
```

#### Step _run_Align_gz_P157t

```
du -b Z00???t/*
680982724	Z00599t/Z00599t.trim.bwa.sorted.bam
1461584	Z00599t/Z00599t.trim.bwa.sorted.bam.bai
395	Z00599t/Z00599t.trim.bwa.sorted.flagstat
671161281	Z00600t/Z00600t.trim.bwa.sorted.bam
1560464	Z00600t/Z00600t.trim.bwa.sorted.bam.bai
396	Z00600t/Z00600t.trim.bwa.sorted.flagstat
616358782	Z00601t/Z00601t.trim.bwa.sorted.bam
1648808	Z00601t/Z00601t.trim.bwa.sorted.bam.bai
397	Z00601t/Z00601t.trim.bwa.sorted.flagstat
```

#### Step _run_Recal_P157_3t

```
du -bc Patient157t/*

2379976  Patient157t/germline
1195  Patient157t/Patient157t.merged.realigned.mateFixed.metrics
1653  Patient157t/Z00599t.bwa.realigned.rmDups.recal.alignment_summary_metrics
1428857220  Patient157t/Z00599t.bwa.realigned.rmDups.recal.bam
1462016  Patient157t/Z00599t.bwa.realigned.rmDups.recal.bam.bai
395   Patient157t/Z00599t.bwa.realigned.rmDups.recal.flagstat
1749  Patient157t/Z00599t.bwa.realigned.rmDups.recal.hybrid_selection_metrics
13562 Patient157t/Z00599t.bwa.realigned.rmDups.recal.insert_size_histogram.pdf
10491 Patient157t/Z00599t.bwa.realigned.rmDups.recal.insert_size_metrics
7785  Patient157t/Z00599t.bwa.realigned.rmDups.recal.quality_by_cycle_metrics
9747  Patient157t/Z00599t.bwa.realigned.rmDups.recal.quality_by_cycle.pdf
1351  Patient157t/Z00599t.bwa.realigned.rmDups.recal.quality_distribution_metrics
5482  Patient157t/Z00599t.bwa.realigned.rmDups.recal.quality_distribution.pdf
1657  Patient157t/Z00600t.bwa.realigned.rmDups.recal.alignment_summary_metrics
1421701825  Patient157t/Z00600t.bwa.realigned.rmDups.recal.bam
1561296  Patient157t/Z00600t.bwa.realigned.rmDups.recal.bam.bai
395   Patient157t/Z00600t.bwa.realigned.rmDups.recal.flagstat
1748  Patient157t/Z00600t.bwa.realigned.rmDups.recal.hybrid_selection_metrics
12895 Patient157t/Z00600t.bwa.realigned.rmDups.recal.insert_size_histogram.pdf
10135 Patient157t/Z00600t.bwa.realigned.rmDups.recal.insert_size_metrics
7778  Patient157t/Z00600t.bwa.realigned.rmDups.recal.quality_by_cycle_metrics
9753  Patient157t/Z00600t.bwa.realigned.rmDups.recal.quality_by_cycle.pdf
1353  Patient157t/Z00600t.bwa.realigned.rmDups.recal.quality_distribution_metrics
5401  Patient157t/Z00600t.bwa.realigned.rmDups.recal.quality_distribution.pdf
1652  Patient157t/Z00601t.bwa.realigned.rmDups.recal.alignment_summary_metrics
1110728442  Patient157t/Z00601t.bwa.realigned.rmDups.recal.bam
1649288  Patient157t/Z00601t.bwa.realigned.rmDups.recal.bam.bai
391   Patient157t/Z00601t.bwa.realigned.rmDups.recal.flagstat
1743  Patient157t/Z00601t.bwa.realigned.rmDups.recal.hybrid_selection_metrics
12047 Patient157t/Z00601t.bwa.realigned.rmDups.recal.insert_size_histogram.pdf
9141  Patient157t/Z00601t.bwa.realigned.rmDups.recal.insert_size_metrics
7792  Patient157t/Z00601t.bwa.realigned.rmDups.recal.quality_by_cycle_metrics
9925  Patient157t/Z00601t.bwa.realigned.rmDups.recal.quality_by_cycle.pdf
1340  Patient157t/Z00601t.bwa.realigned.rmDups.recal.quality_distribution_metrics
5446  Patient157t/Z00601t.bwa.realigned.rmDups.recal.quality_distribution.pdf
3968494065  total

du -bc Patient157t/germline/*
du -bc Patient157t/germline/*
122	Patient157t/germline/NOR-Z00599t_vs_Z00600t.germline
122	Patient157t/germline/NOR-Z00599t_vs_Z00601t.germline
2358600	Patient157t/germline/Patient157t.UG.snps.vcf
20986	Patient157t/germline/Patient157t.UG.snps.vcf.idx
2379830	total
```

#### Step _run_Pindel_157t

```
du -b Patient157t.pindel.cfg
369	Patient157t.pindel.cfg

du -bc Patient157t_pindel/*
3229368	Patient157t_pindel/Patient157t.indels
1832	Patient157t_pindel/Patient157t.indels.filtered.anno.txt
0	Patient157t_pindel/Patient157t.pindel_BP
0	Patient157t_pindel/Patient157t.pindel_CloseEndMapped
68469953	Patient157t_pindel/Patient157t.pindel_D
0	Patient157t_pindel/Patient157t.pindel_INV
0	Patient157t_pindel/Patient157t.pindel_LI
67438017	Patient157t_pindel/Patient157t.pindel_SI
0	Patient157t_pindel/Patient157t.pindel_TD
1750109	Patient157t_pindel/Patient157t.pindel.vcf
140889279	total
```

#### Step _run_MutDet_P157t

```
du -bc Patient157t_mutect/*
961948	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.indels.annotated.vcf
1962	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.indels.annotated.vcf.idx
733932	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.indels.raw.vcf
1956	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.indels.raw.vcf.idx
11128	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.mutations
679946	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.snvs.coverage.mutect.bed
34419805	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.snvs.coverage.mutect.wig
3813338	Patient157t_mutect/NOR-Z00599t__REC1-Z00601t.snvs.raw.mutect.txt
1098768	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.indels.annotated.vcf
1961	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.indels.annotated.vcf.idx
837870	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.indels.raw.vcf
1955	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.indels.raw.vcf.idx
6538	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.mutations
636548	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.snvs.coverage.mutect.bed
34468853	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.snvs.coverage.mutect.wig
4087100	Patient157t_mutect/NOR-Z00599t__TUM-Z00600t.snvs.raw.mutect.txt
2489512	Patient157t_mutect/Patient157t.mutect.coverage.intersect.bed
20843	Patient157t_mutect/Patient157t.NOR-Z00599t__REC1-Z00601t.annotated.mutations
10621	Patient157t_mutect/Patient157t.NOR-Z00599t__TUM-Z00600t.annotated.mutations
84284584	total
```

#### Step _run_PostMut_P157t

```
du -bc Patient157t*
3220	Patient157t.R.mutations
30686	Patient157t.snvs
7237	Patient157t.snvs.anno.pat.filt.txt
34128	Patient157t.snvs.anno.pat.txt
33580	Patient157t.snvs.anno.txt
2982	Patient157t.snvs.indels.filtered.overlaps.txt
9438	Patient157t.snvs.indels.filtered.txt
121271	total

du -bc Patient157t_MAF/*
105311	Patient157t_MAF/Patient157t.Normal.MAF.txt
104985	Patient157t_MAF/Patient157t.Primary.MAF.txt
104672	Patient157t_MAF/Patient157t.Recurrence1.MAF.txt
314968	total

du -bc Patient157t_plots/*
du -bc Patient157t_plots/*
34718	Patient157t_plots/Patient157t.LOH.chr17.pdf
41728	Patient157t_plots/Patient157t.LOH.chr19.pdf
44632	Patient157t_plots/Patient157t.LOH.grid.chr17.pdf
54011	Patient157t_plots/Patient157t.LOH.grid.chr19.pdf
175089	total
```

