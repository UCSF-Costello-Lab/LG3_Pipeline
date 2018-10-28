args <- commandArgs(trailingOnly = TRUE)
pat <- args[1]
proj <- args[2]
conv <- args[3]

lg3_home <- Sys.getenv("LG3_HOME")
if (!nzchar(lg3_home)) stop("'LG3_HOME' is not set")

wdir <- file.path(Sys.getenv("LG3_INPUT_ROOT", "rawdata"), proj, "MAF")
setwd(wdir)

source(file.path(lg3_home, "scripts/MAFplot_version3.R"))

dd <- loadMAF(pat)

##### modified by Ivan
chrs <- unique(dd[[pat]]$chromosome)
chrs.num <- length(chrs)
## standardize chromosome notation (1-24, no "chr")
chrs <- gsub("chr", "", chrs)
chrs[chrs == "X"] <- 23
chrs[chrs == "Y"] <- 24
chrs <- as.numeric(as.vector(chrs))
cat("Found ", chrs.num, "chromosomes\n")
print(chrs)

if (chrs.num > 22) {
  cat("Whole genome LOH plot\n")
  png(paste0(pat, "_plots/", pat, ".LOH.png"), width = 10, height = 4, units = "in", res = 300)
  plotMAF(dd, conv, pat)
  dev.off()
} else {
  cat("Only ", chrs.num, "chromosomes available, skiping whole genome plot\n")
}

for (c in chrs) {
  cat("LOH plot for chr", c, "\n")
  pdf(paste0(pat, "_plots/", pat, ".LOH.chr", c, ".pdf"), width = 10, height = 4)
  plotMAF(dd, conv, pat, ch = c)
  dev.off()
}

if (length(unique(dd[[pat]]$samp)) > 2) {
  source(file.path(lg3_home, "scripts/MAFplot_version3_grid.R"))
  dd <- loadMAF(pat)
  for (c in chrs) {
    cat("Grid plot for chr", c, "\n")
    pdf(paste0(pat, "_plots/", pat, ".LOH.grid.chr", c, ".pdf"), width = 12, height = 6)
    plotMAF(dd, conv, pat, ch = c, grid = TRUE)
    dev.off()
  }
}
