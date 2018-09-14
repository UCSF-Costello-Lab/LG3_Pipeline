args <- commandArgs(trailingOnly = TRUE)
pat <- args[1]
proj <- args[2]
conv <- args[3]

wdir <- file.path(Sys.getenv("LG3_INPUT_ROOT", "/costellolab/data1/jocostello"), proj, "MAF")
message("Setting work directory: ", sQuote(wdir))
setwd(wdir)

source(file.path(Sys.getenv("LG3_HOME", "/home/jocostello/shared/LG3_Pipeline"), "scripts/MAFplot_version3.R"))

message("1. Loading patient data: ", sQuote(pat))
dd <- loadMAF(pat)
str(dd)

uchrs <- sort(unique(dd[[pat]]$chromosome))
uchrs <- as.integer(gsub("chr", "", uchrs))
nchrs <- length(uchrs)
message(sprintf("Chromsomes: [n=%d] %s", nchrs, paste(uchrs, collapse = ", ")))

message("2. plotMAF()")
if (nchrs >= 23) {
  #png(paste0(pat,"_plots/",pat,".LOH.png"), width=1000, height=400)
  png(paste0(pat,"_plots/",pat,".LOH.png"), width=10, height=4, units="in", res=300)
  plotMAF(dd,conv,pat)
  dev.off()
}

message("3. plotMAF() per chromosome")
for(c in uchrs) {
  pdf(paste0(pat,"_plots/",pat,".LOH.chr",c,".pdf"), width=10, height=4)
  plotMAF(dd,conv,pat,ch=c)
  dev.off()
}

if(length(unique(dd[[pat]]$samp)) > 2) {
  source(file.path(Sys.getenv("LG3_HOME", "/home/jocostello/shared/LG3_Pipeline"), "scripts/MAFplot_version3_grid.R"))
  message("4. Loading patient data: ", sQuote(pat))
  dd <- loadMAF(pat)
  str(dd)
  
  uchrs <- sort(unique(dd[[pat]]$chromosome))
  uchrs <- as.integer(gsub("chr", "", uchrs))
  nchrs <- length(uchrs)
  message(sprintf("Chromsomes: [n=%d] %s", nchrs, paste(uchrs, collapse = ", ")))

  message("5. plotMAF() per chromosome")
  for(c in uchrs) {
    pdf(paste0(pat,"_plots/",pat,".LOH.grid.chr",c,".pdf"), width=12, height=6)
    plotMAF(dd,conv,pat,ch=c, grid=TRUE)
    dev.off()
  }
}

