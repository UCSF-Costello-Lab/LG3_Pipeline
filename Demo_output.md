### Expected output files and sizes for demo/test run

#### Step _run_trim_P157

```
du -b Z00599-trim/*
4541591250	Z00599-trim/Z00599-trim_R1.fastq.gz
3809	Z00599-trim/Z00599-trim_R1.trimming_report.txt
4787364118	Z00599-trim/Z00599-trim_R2.fastq.gz
4011	Z00599-trim/Z00599-trim_R2.trimming_report.txt

du -b Z00600-trim/*
4860153452	Z00600-trim/Z00600-trim_R1.fastq.gz
3832	Z00600-trim/Z00600-trim_R1.trimming_report.txt
5029394683	Z00600-trim/Z00600-trim_R2.fastq.gz
4044	Z00600-trim/Z00600-trim_R2.trimming_report.txt

fastq]$ du -b Z00601-trim/*
6021054501	Z00601-trim/Z00601-trim_R1.fastq.gz
3853	Z00601-trim/Z00601-trim_R1.trimming_report.txt
6312584266	Z00601-trim/Z00601-trim_R2.fastq.gz
4047	Z00601-trim/Z00601-trim_R2.trimming_report.txt
```

#### Step _run_Align_gz_P157

```
du -b Z00599/*
6416408982	Z00599/Z00599.trim.bwa.sorted.bam
6050968	Z00599/Z00599.trim.bwa.sorted.bam.bai
412	Z00599/Z00599.trim.bwa.sorted.flagstat

du -b Z00600/*
6793610227	Z00600/Z00600.trim.bwa.sorted.bam
6204640	Z00600/Z00600.trim.bwa.sorted.bam.bai
412	Z00600/Z00600.trim.bwa.sorted.flagstat

du -b Z00601/*
8345393162	Z00601/Z00601.trim.bwa.sorted.bam
6248072	Z00601/Z00601.trim.bwa.sorted.bam.bai
414	Z00601/Z00601.trim.bwa.sorted.flagstat
```

#### Step _run_Recal_P157_3

```
du -bc Patient157/*

20255862	Patient157/germline
1232	Patient157/Patient157.merged.realigned.mateFixed.metrics

1705	Patient157/Z00599.bwa.realigned.rmDups.recal.alignment_summary_metrics
12964344255	Patient157/Z00599.bwa.realigned.rmDups.recal.bam
6067128	Patient157/Z00599.bwa.realigned.rmDups.recal.bam.bai
411	Patient157/Z00599.bwa.realigned.rmDups.recal.flagstat
1754	Patient157/Z00599.bwa.realigned.rmDups.recal.hybrid_selection_metrics
14220	Patient157/Z00599.bwa.realigned.rmDups.recal.insert_size_histogram.pdf
12202	Patient157/Z00599.bwa.realigned.rmDups.recal.insert_size_metrics
7780	Patient157/Z00599.bwa.realigned.rmDups.recal.quality_by_cycle_metrics
9780	Patient157/Z00599.bwa.realigned.rmDups.recal.quality_by_cycle.pdf
1357	Patient157/Z00599.bwa.realigned.rmDups.recal.quality_distribution_metrics
5323	Patient157/Z00599.bwa.realigned.rmDups.recal.quality_distribution.pdf

1704	Patient157/Z00600.bwa.realigned.rmDups.recal.alignment_summary_metrics
13945305430	Patient157/Z00600.bwa.realigned.rmDups.recal.bam
6224408	Patient157/Z00600.bwa.realigned.rmDups.recal.bam.bai
412	Patient157/Z00600.bwa.realigned.rmDups.recal.flagstat
1755	Patient157/Z00600.bwa.realigned.rmDups.recal.hybrid_selection_metrics
13677	Patient157/Z00600.bwa.realigned.rmDups.recal.insert_size_histogram.pdf
11863	Patient157/Z00600.bwa.realigned.rmDups.recal.insert_size_metrics
7782	Patient157/Z00600.bwa.realigned.rmDups.recal.quality_by_cycle_metrics
9735	Patient157/Z00600.bwa.realigned.rmDups.recal.quality_by_cycle.pdf
1364	Patient157/Z00600.bwa.realigned.rmDups.recal.quality_distribution_metrics
5439	Patient157/Z00600.bwa.realigned.rmDups.recal.quality_distribution.pdf

1701	Patient157/Z00601.bwa.realigned.rmDups.recal.alignment_summary_metrics
14840706212	Patient157/Z00601.bwa.realigned.rmDups.recal.bam
6265328	Patient157/Z00601.bwa.realigned.rmDups.recal.bam.bai
413	Patient157/Z00601.bwa.realigned.rmDups.recal.flagstat
1756	Patient157/Z00601.bwa.realigned.rmDups.recal.hybrid_selection_metrics
13212	Patient157/Z00601.bwa.realigned.rmDups.recal.insert_size_histogram.pdf
11322	Patient157/Z00601.bwa.realigned.rmDups.recal.insert_size_metrics
7778	Patient157/Z00601.bwa.realigned.rmDups.recal.quality_by_cycle_metrics
9863	Patient157/Z00601.bwa.realigned.rmDups.recal.quality_by_cycle.pdf
1339	Patient157/Z00601.bwa.realigned.rmDups.recal.quality_distribution_metrics
5358	Patient157/Z00601.bwa.realigned.rmDups.recal.quality_distribution.pdf
41789330860	total

du -bc Patient157/germline/*
122	Patient157/germline/NOR-Z00599_vs_Z00600.germline
122	Patient157/germline/NOR-Z00599_vs_Z00601.germline
19539448	Patient157/germline/Patient157.UG.snps.vcf
716030	Patient157/germline/Patient157.UG.snps.vcf.idx
20255722	total
```

#### Step _run_Pindel_157

```
du -b Patient157.pindel.cfg
360	Patient157.pindel.cfg

du -bc Patient157_pindel/*
32055748	Patient157_pindel/Patient157.indels
19299	Patient157_pindel/Patient157.indels.filtered.anno.txt
0	Patient157_pindel/Patient157.pindel_BP
0	Patient157_pindel/Patient157.pindel_CloseEndMapped
722371718	Patient157_pindel/Patient157.pindel_D
26576	Patient157_pindel/Patient157.pindel_INV
0	Patient157_pindel/Patient157.pindel_LI
706464458	Patient157_pindel/Patient157.pindel_SI
0	Patient157_pindel/Patient157.pindel_TD
17669654	Patient157_pindel/Patient157.pindel.vcf
1478607453	total
```

#### Step _run_MutDet_P157

```
du -bc Patient157_mutect/*
9266892	Patient157_mutect/NOR-Z00599__REC1-Z00601.indels.annotated.vcf
25548	Patient157_mutect/NOR-Z00599__REC1-Z00601.indels.annotated.vcf.idx
7075670	Patient157_mutect/NOR-Z00599__REC1-Z00601.indels.raw.vcf
25542	Patient157_mutect/NOR-Z00599__REC1-Z00601.indels.raw.vcf.idx
116231	Patient157_mutect/NOR-Z00599__REC1-Z00601.mutations
6643307	Patient157_mutect/NOR-Z00599__REC1-Z00601.snvs.coverage.mutect.bed
326870024	Patient157_mutect/NOR-Z00599__REC1-Z00601.snvs.coverage.mutect.wig
35685877	Patient157_mutect/NOR-Z00599__REC1-Z00601.snvs.raw.mutect.txt
9723051	Patient157_mutect/NOR-Z00599__TUM-Z00600.indels.annotated.vcf
25555	Patient157_mutect/NOR-Z00599__TUM-Z00600.indels.annotated.vcf.idx
7418045	Patient157_mutect/NOR-Z00599__TUM-Z00600.indels.raw.vcf
26013	Patient157_mutect/NOR-Z00599__TUM-Z00600.indels.raw.vcf.idx
52919	Patient157_mutect/NOR-Z00599__TUM-Z00600.mutations
6581061	Patient157_mutect/NOR-Z00599__TUM-Z00600.snvs.coverage.mutect.bed
327214590	Patient157_mutect/NOR-Z00599__TUM-Z00600.snvs.coverage.mutect.wig
35182483	Patient157_mutect/NOR-Z00599__TUM-Z00600.snvs.raw.mutect.txt
23720611	Patient157_mutect/Patient157.mutect.coverage.intersect.bed
217436	Patient157_mutect/Patient157.NOR-Z00599__REC1-Z00601.annotated.mutations
93625	Patient157_mutect/Patient157.NOR-Z00599__TUM-Z00600.annotated.mutations
795964480	total
```

#### Step _run_PostMut_P157

```
du -bc *
27515	Patient157.R.mutations
307617	Patient157.snvs
48858	Patient157.snvs.anno.pat.filt.txt
342484	Patient157.snvs.anno.pat.txt
335882	Patient157.snvs.anno.txt
25702	Patient157.snvs.indels.filtered.overlaps.txt
76006	Patient157.snvs.indels.filtered.txt
1164064	total

du -bc Patient157_MAF/*
817903	Patient157_MAF/Patient157.Normal.MAF.txt
817204	Patient157_MAF/Patient157.Primary.MAF.txt
813175	Patient157_MAF/Patient157.Recurrence1.MAF.txt
2448282	total

du -bc Patient157_plots/*
27650	Patient157_plots/Patient157.LOH.chr10.pdf
30779	Patient157_plots/Patient157.LOH.chr11.pdf
30406	Patient157_plots/Patient157.LOH.chr12.pdf
13757	Patient157_plots/Patient157.LOH.chr13.pdf
23959	Patient157_plots/Patient157.LOH.chr14.pdf
21537	Patient157_plots/Patient157.LOH.chr15.pdf
28695	Patient157_plots/Patient157.LOH.chr16.pdf
34790	Patient157_plots/Patient157.LOH.chr17.pdf
13800	Patient157_plots/Patient157.LOH.chr18.pdf
41900	Patient157_plots/Patient157.LOH.chr19.pdf
57093	Patient157_plots/Patient157.LOH.chr1.pdf
18798	Patient157_plots/Patient157.LOH.chr20.pdf
12402	Patient157_plots/Patient157.LOH.chr21.pdf
17135	Patient157_plots/Patient157.LOH.chr22.pdf
12889	Patient157_plots/Patient157.LOH.chr23.pdf
4931	Patient157_plots/Patient157.LOH.chr24.pdf
44137	Patient157_plots/Patient157.LOH.chr2.pdf
35331	Patient157_plots/Patient157.LOH.chr3.pdf
27020	Patient157_plots/Patient157.LOH.chr4.pdf
30323	Patient157_plots/Patient157.LOH.chr5.pdf
33983	Patient157_plots/Patient157.LOH.chr6.pdf
32790	Patient157_plots/Patient157.LOH.chr7.pdf
21982	Patient157_plots/Patient157.LOH.chr8.pdf
25350	Patient157_plots/Patient157.LOH.chr9.pdf
35082	Patient157_plots/Patient157.LOH.grid.chr10.pdf
39214	Patient157_plots/Patient157.LOH.grid.chr11.pdf
38916	Patient157_plots/Patient157.LOH.grid.chr12.pdf
16892	Patient157_plots/Patient157.LOH.grid.chr13.pdf
30116	Patient157_plots/Patient157.LOH.grid.chr14.pdf
27164	Patient157_plots/Patient157.LOH.grid.chr15.pdf
36646	Patient157_plots/Patient157.LOH.grid.chr16.pdf
44684	Patient157_plots/Patient157.LOH.grid.chr17.pdf
17021	Patient157_plots/Patient157.LOH.grid.chr18.pdf
54096	Patient157_plots/Patient157.LOH.grid.chr19.pdf
73894	Patient157_plots/Patient157.LOH.grid.chr1.pdf
23544	Patient157_plots/Patient157.LOH.grid.chr20.pdf
15108	Patient157_plots/Patient157.LOH.grid.chr21.pdf
21270	Patient157_plots/Patient157.LOH.grid.chr22.pdf
15737	Patient157_plots/Patient157.LOH.grid.chr23.pdf
4994	Patient157_plots/Patient157.LOH.grid.chr24.pdf
56963	Patient157_plots/Patient157.LOH.grid.chr2.pdf
45418	Patient157_plots/Patient157.LOH.grid.chr3.pdf
34469	Patient157_plots/Patient157.LOH.grid.chr4.pdf
38734	Patient157_plots/Patient157.LOH.grid.chr5.pdf
43552	Patient157_plots/Patient157.LOH.grid.chr6.pdf
41937	Patient157_plots/Patient157.LOH.grid.chr7.pdf
27554	Patient157_plots/Patient157.LOH.grid.chr8.pdf
32183	Patient157_plots/Patient157.LOH.grid.chr9.pdf
230204	Patient157_plots/Patient157.LOH.png
1686829	total
```
