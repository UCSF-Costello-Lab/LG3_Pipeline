path <- Sys.getenv("LG3_OUTPUT_PATH", "output")
stopifnot(file_test("-d", path))

truth <- list(
  "Z00599-trim/Z00599-trim_R1.fastq.gz"            = list(size = 4541591250),
  "Z00599-trim/Z00599-trim_R2.fastq.gz"            = list(size = 4787364118),
  "Z00599-trim/Z00599-trim_R1.trimming_report.txt" = list(size = 3809 + c(-1, 1)*10),
  "Z00599-trim/Z00599-trim_R2.trimming_report.txt" = list(size = 4011 + c(-1, 1)*10),
  "Z00600-trim/Z00600-trim_R1.fastq.gz"            = list(size = 4860153452),
  "Z00600-trim/Z00600-trim_R2.fastq.gz"            = list(size = 5029394683),
  "Z00600-trim/Z00600-trim_R1.trimming_report.txt" = list(size = 3832 + c(-1, 1)*10),
  "Z00600-trim/Z00600-trim_R2.trimming_report.txt" = list(size = 4044 + c(-1, 1)*10),
  "Z00601-trim/Z00601-trim_R1.fastq.gz"            = list(size = 6021054501),
  "Z00601-trim/Z00601-trim_R2.fastq.gz"            = list(size = 6312584266),
  "Z00601-trim/Z00601-trim_R1.trimming_report.txt" = list(size = 3853 + c(-1, 1)*10),
  "Z00601-trim/Z00601-trim_R2.trimming_report.txt" = list(size = 4047 + c(-1, 1)*10)
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
