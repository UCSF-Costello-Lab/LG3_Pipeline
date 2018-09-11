path <- Sys.getenv("LG3_OUTPUT_PATH", "output")
stopifnot(file_test("-d", path))

path <- file.path(path, "LG3", "exomes")
stopifnot(file_test("-d", path))

truth <- list(
  "Z00599/Z00599.trim.bwa.sorted.bam"      = list(size = 6416408982),
  "Z00599/Z00599.trim.bwa.sorted.bam.bai"  = list(size = 6050968),
  "Z00599/Z00599.trim.bwa.sorted.flagstat" = list(size = 412),
  "Z00600/Z00600.trim.bwa.sorted.bam"      = list(size = 6793610227),
  "Z00600/Z00600.trim.bwa.sorted.bam.bai"  = list(size = 6204640),
  "Z00600/Z00600.trim.bwa.sorted.flagstat" = list(size = 412),
  "Z00601/Z00601.trim.bwa.sorted.bam"      = list(size = 8345393162),
  "Z00601/Z00601.trim.bwa.sorted.bam.bai"  = list(size = 6248072),
  "Z00601/Z00601.trim.bwa.sorted.flagstat" = list(size = 414)
)

for (kk in seq_along(truth)) {
	file <- names(truth)[kk]
	pathname <- file.path(path, file)
	size <- file.size(pathname)
	cat(sprintf("- %s: %.0f bytes\n", pathname, size))
	stopifnot(file_test("-f", pathname))
	expected <- truth[[file]]$size
	if (length(expected) == 1L) {
	       stopifnot(size == expected)
	} else {
	       stopifnot(expected[1] <= size || size <= expected[2])
	}
	
}
