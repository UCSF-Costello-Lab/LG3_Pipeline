args <- commandArgs(trailingOnly = TRUE)

snvs <- read.delim(args[1], as.is=TRUE)
indels <- read.delim(args[2], as.is=TRUE)

both <- merge(snvs, indels, all=TRUE)
names(both)[1] <- "#gene"

write.table(both, file=args[3], quote=FALSE, sep="\t", row.names=FALSE, col.names=TRUE)


