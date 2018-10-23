assertFile <- function(pathname) {
  if (!utils::file_test("-f", pathname)) {
    pathnameX <- normalizePath(pathname, mustWork = FALSE)
    stop(sprintf("File not found: %s => %s (current working directory is %s)", sQuote(pathname), sQuote(pathnameX), sQuote(getwd())))
  }
  invisible(pathname)
}

args <- commandArgs(trailingOnly = TRUE)

infile <- args[1]
outfile <- args[2]
# stfa <- args[3]  ## sample_to_filter_against (ie Normal, or Primary if no Normal)

assertFile(infile)
data <- read.delim(infile, as.is = TRUE)

alg <- which(data$algorithm == "SomaticIndelDetector")
oj <- which(data$ourJudgment == "no")
norm.alt <- which(data$Normal_alt_reads > 5 | data$Normal_alt_reads / (data$Normal_alt_reads + data$Normal_ref_reads) > 0.1)
### norm.alt <- which(data[ , paste0(stfa, "_alt_reads")] > 5 | data[ , paste0(stfa, "_alt_reads")] / ( data[ , paste0(stfa, "_alt_reads")] + data[ , paste0(stfa, "_ref_reads")] ) > 0.1 )
toremove <- c(alg, oj, norm.alt)
# toremove <- c(alg, oj)

data <- data[-toremove, ]
names(data)[1] <- "#gene"

write.table(data, file = outfile, quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)
