args <- commandArgs(trailingOnly = TRUE)

outfile <- args[length(args)]
tomerge <- args[-length(args)]

print(tomerge[1])
final <- read.delim(tomerge[1], as.is=TRUE)
for(i in tomerge[-1]) {
  print(i)
  temp <- read.delim(i, as.is=TRUE)
  final <- merge(final, temp, all=TRUE)
}
names(final)[1] <- "#gene"

print(outfile)
write.table(final, file=outfile, quote=FALSE, sep="\t", row.names=FALSE, col.names=TRUE)

