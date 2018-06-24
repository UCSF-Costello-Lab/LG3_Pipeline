args <- commandArgs(trailingOnly = TRUE)
pat <- args[1]
proj <- args[2]
conv <- args[3]

setwd(paste0("/costellolab/jocostello/",proj,"/MAF/"))
#setwd("/costellolab/jocostello/LG3/MAF/")

source("/home/jocostello/shared/LG3_Pipeline/scripts/MAFplot_version3.R")

dd <- loadMAF(pat)

#png(paste0(pat,"_plots/",pat,".LOH.png"), width=1000, height=400)
png(paste0(pat,"_plots/",pat,".LOH.png"), width=10, height=4, units="in", res=300)
plotMAF(dd,conv,pat)
dev.off()

chrs <- 1:24
for(c in chrs) {
  pdf(paste0(pat,"_plots/",pat,".LOH.chr",c,".pdf"), width=10, height=4)
  plotMAF(dd,conv,pat,ch=c)
  dev.off()
}

if(length(unique(dd[[pat]]$samp)) > 2) {
  source("/home/jocostello/shared/LG3_Pipeline/scripts/MAFplot_version3_grid.R")
  dd <- loadMAF(pat)
  chrs <- 1:24
  for(c in chrs) {
    pdf(paste0(pat,"_plots/",pat,".LOH.grid.chr",c,".pdf"), width=12, height=6)
    plotMAF(dd,pat,ch=c, grid=TRUE)
    dev.off()
  }
}

