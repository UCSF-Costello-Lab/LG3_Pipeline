#### R script: mutations_annotate_intersected_coverage.R
### INPUTS:
## 1. output of multiIntersectedBed (from /.../LG3_TOOLS/python/convert_patient_wig2bed.py)
## 2. mutation list (*filtered.overlaps.txt)
## 3. output file name
### FUNCTION:
## annotates mutation list with whether or not MuTect considered that site covered in ALL tumors

assertFile <- function(pathname) {
  if (!utils::file_test("-f", pathname)) {
    pathnameX <- normalizePath(pathname, mustWork = FALSE)
    stop(sprintf("File not found: %s => %s (current working directory is %s)", sQuote(pathname), sQuote(pathnameX), sQuote(getwd())))
  }
  invisible(pathname)
}

args <- commandArgs(trailingOnly = TRUE)

## get files names
bedfile <- args[1]
overlapsfile <- args[2]
mutfile <- sub("overlaps.", "", overlapsfile)
tmp.file.header <- paste0(overlapsfile, "_TMP_")
outfile <- args[3]

assertFile(bedfile)
assertFile(overlapsfile)
assertFile(mutfile)

## read in data
dat.bed <- read.delim(bedfile, sep = "\t", as.is = TRUE, header = FALSE)
dat.overlaps <- read.delim(overlapsfile, sep = "\t", as.is = TRUE, header = TRUE)
dat.muts <- read.delim(mutfile, sep = "\t", as.is = TRUE, header = TRUE)

## pull out the coordinates that are covered in ALL tumors
toselect <- paste(1:length(unique(dat.muts$sample_type)), collapse = ",")
if (length(unique(dat.muts$sample_type)) == 1) {
  covered.in.all <- dat.bed
} else {
  covered.in.all <- dat.bed[which(dat.bed[, 4] == length(unique(dat.muts$sample_type))), 1:3]
}
write.table(covered.in.all, file = paste0(tmp.file.header, "coveredinall.bed"), col.names = FALSE, row.names = FALSE, sep = "\t", quote = FALSE)

## write a temp bed file of all the MuTect mutation coordinates
write.table(dat.overlaps[which(dat.overlaps$algorithm == "MuTect"), c(2, 3, 3)], file = paste0(tmp.file.header, "muts.bed"), col.names = FALSE, row.names = FALSE, quote = FALSE, sep = "\t")

## run bedtools intersect
bin <- file.path(dirname(Sys.getenv("BEDTOOLS")), "intersectBed")
stopifnot(file.exists(bin))
system(paste0(bin, " -wa -a ", tmp.file.header, "muts.bed -b ", tmp.file.header, "coveredinall.bed > ", tmp.file.header, "intersect.bed"), wait = TRUE)
bedfile2 <- paste0(tmp.file.header, "intersect.bed")
assertFile(bedfile2)
intersect.bed <- read.table(bedfile2, header = FALSE, as.is = TRUE)
intersect.bed.nameuniq <- paste(intersect.bed[, 1], intersect.bed[, 2], sep = "_")

## annotate the mutations that are covered in all
dat.overlaps$mutect_covered_in_all <- NA
dat.overlaps.nameuniq <- paste(dat.overlaps$contig, dat.overlaps$position, sep = "_")
dat.overlaps$mutect_covered_in_all[which(dat.overlaps.nameuniq %in% intersect.bed.nameuniq)] <- "covered_in_all"
dat.overlaps <- dat.overlaps[, c(1:9, ncol(dat.overlaps), 10:(ncol(dat.overlaps) - 1))]

## write to outfile
names(dat.overlaps)[1] <- "#gene"
write.table(dat.overlaps, file = outfile, quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)

## clean up temp files
system(paste0("rm ", tmp.file.header, "*"), wait = TRUE)
