path <- Sys.getenv("LG3_OUTPUT_PATH", "output")
stopifnot(file_test("-d", path))

path <- file.path(path, "LG3", "exomes_recal")
stopifnot(file_test("-d", path))

truth <- list(
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
