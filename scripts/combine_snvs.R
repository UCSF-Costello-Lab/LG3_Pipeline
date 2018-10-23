assertFile <- function(pathname) {
  if (!utils::file_test("-f", pathname)) {
    pathnameX <- normalizePath(pathname, mustWork = FALSE)
    stop(sprintf("File not found: %s => %s (current working directory is %s)", sQuote(pathname), sQuote(pathnameX), sQuote(getwd())))
  }
  invisible(pathname)
}

args <- commandArgs(trailingOnly = TRUE)

outfile <- args[length(args)]
tomerge <- args[-length(args)]

print(tomerge[1])
assertFile(tomerge[1])
final <- read.delim(tomerge[1], as.is=TRUE)
for(i in tomerge[-1]) {
  print(i)
  assertFile(i)
  temp <- read.delim(i, as.is=TRUE)
  final <- merge(final, temp, all=TRUE)
}
names(final)[1] <- "#gene"

print(outfile)
write.table(final, file=outfile, quote=FALSE, sep="\t", row.names=FALSE, col.names=TRUE)

