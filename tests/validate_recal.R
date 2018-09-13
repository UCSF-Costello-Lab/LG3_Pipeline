path <- Sys.getenv("LG3_OUTPUT_PATH", "output")
stopifnot(file_test("-d", path))

path <- file.path(path, "LG3", "exomes_recal")
stopifnot(file_test("-d", path))

truth <- list(
  "Patient157/Patient157.merged.realigned.mateFixed.metrics" = list(size = 1232 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.alignment_summary_metrics" = list(size = 1705 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.bam" = list(size = 12964344255 + c(-1,+1)*30e6),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.bam.bai" = list(size = 6067128 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.flagstat" = list(size = 411 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.hybrid_selection_metrics" = list(size = 1754 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.insert_size_histogram.pdf" = list(size = 14220 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.insert_size_metrics" = list(size = 12202 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.quality_by_cycle_metrics" = list(size = 7780 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.quality_by_cycle.pdf" = list(size = 9780 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.quality_distribution_metrics" = list(size = 1357 + c(-1,+1)*30),
  "Patient157/Z00599.bwa.realigned.rmDups.recal.quality_distribution.pdf" = list(size = 5323 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.alignment_summary_metrics" = list(size = 1704 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.bam" = list(size = 13945305430 + c(-1,+1)*10e6),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.bam.bai" = list(size = 6224408 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.flagstat" = list(size = 412 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.hybrid_selection_metrics" = list(size = 1755 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.insert_size_histogram.pdf" = list(size = 13677 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.insert_size_metrics" = list(size = 11863 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.quality_by_cycle_metrics" = list(size = 7782 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.quality_by_cycle.pdf" = list(size = 9735 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.quality_distribution_metrics" = list(size = 1364 + c(-1,+1)*30),
  "Patient157/Z00600.bwa.realigned.rmDups.recal.quality_distribution.pdf" = list(size = 5439 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.alignment_summary_metrics" = list(size = 1701 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.bam" = list(size = 14840706212 + c(-1,+1)*10e6),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.bam.bai" = list(size = 6265328 + c(-1,+1)*1e3),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.flagstat" = list(size = 413 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.hybrid_selection_metrics" = list(size = 1756 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.insert_size_histogram.pdf" = list(size = 13212 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.insert_size_metrics" = list(size = 11322 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.quality_by_cycle_metrics" = list(size = 7778 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.quality_by_cycle.pdf" = list(size = 9863 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.quality_distribution_metrics" = list(size = 1339 + c(-1,+1)*30),
  "Patient157/Z00601.bwa.realigned.rmDups.recal.quality_distribution.pdf" = list(size = 5358 + c(-1,+1)*30),
  "Patient157/germline/NOR-Z00599_vs_Z00600.germline" = list(size = 122 + c(-1,+1)*30),
  "Patient157/germline/NOR-Z00599_vs_Z00601.germline" = list(size = 122 + c(-1,+1)*30),
  "Patient157/germline/Patient157.UG.snps.vcf" = list(size = 19539448 + c(-1,+1)*10e3),
  "Patient157/germline/Patient157.UG.snps.vcf.idx" = list(size = 716030 + c(-1,+1)*2e3)
)

for (kk in seq_along(truth)) {
  file <- names(truth)[kk]
  pathname <- file.path(path, file)
  size <- file.size(pathname)
  cat(sprintf("- %s: %.0f bytes\n", pathname, size))
  stopifnot(file_test("-f", pathname))
  expected <- truth[[file]]$size
  if (length(expected) == 1L) {
    if (size != expected) stop(sprintf("Unexpected file size of %s: %.f != %.f bytes", sQuote(file), size, expected))
  } else {
    if (size < expected[1] || size > expected[2]) stop(sprintf("Unexpected file size of %s: %.f != [%.f, %.f] bytes", sQuote(file), size, expected[1], expected[2]))
  }
}
