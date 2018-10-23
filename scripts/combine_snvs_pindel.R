assertFile <- function(pathname) {
  if (!utils::file_test("-f", pathname)) {
    pathnameX <- normalizePath(pathname, mustWork = FALSE)
    stop(sprintf("File not found: %s => %s (current working directory is %s)", sQuote(pathname), sQuote(pathnameX), sQuote(getwd())))
  }
  invisible(pathname)
}

args <- commandArgs(trailingOnly = TRUE)

assertFile(args[1])
assertFile(args[2])

snvs <- read.delim(args[1], as.is=TRUE)
indels <- read.delim(args[2], as.is=TRUE)

both <- merge(snvs, indels, all=TRUE)
names(both)[1] <- "#gene"

write.table(both, file=args[3], quote=FALSE, sep="\t", row.names=FALSE, col.names=TRUE)


