if (system.file(package = "RColorBrewer") == "") install.packages("RColorBrewer")
library(RColorBrewer)

assertFile <- function(pathname) {
  if (!utils::file_test("-f", pathname)) {
    pathnameX <- normalizePath(pathname, mustWork = FALSE)
    stop(sprintf("File not found: %s => %s (current working directory is %s)", sQuote(pathname), sQuote(pathnameX), sQuote(getwd())))
  }
  invisible(pathname)
}

###
# Function to load MAF files for a particular patient
###
loadMAF <- function(pat) {
  files <- dir(paste0(pat, "_MAF"), full.names = TRUE, pattern = "[.]txt$")
  dd <- list()
  for (ff in files) {
    assertFile(ff)
    d <- read.table(ff, header = TRUE, as.is = TRUE, sep = "\t") ## read in a file: data.frame with columns "chromosome" "position" "MAF"
    id <- gsub("(^.*/|[.]MAF.*$)", "", ff) ## "^.*/" removes "MAF/"  and "[.]MAF.*$"  removes the ending ".MAF.txt"
    ptnt <- strsplit(id, "[.]")[[1]][1] ## separate id into patient...
    samp <- strsplit(id, "[.]")[[1]][2] ## ...and sample
    d$samp <- samp
    dd[[ptnt]] <- rbind(dd[[ptnt]], d) ## add this data to the full list, to the dataframe for the correct patient
  }
  return(dd)
}

######################################################################
# Function to plot any individual chromosome or the whole genome
######################################################################

plotMAF <- function(dd, convFILE, samp = NA, ch = NA, pos = NA, gene = NA, grid = FALSE) {
  ## FIXME: Constants used
  lg3_home <- Sys.getenv("LG3_HOME")
  if (!nzchar(lg3_home)) stop("'LG3_HOME' is not set")
  pathnameFAI <- file.path(lg3_home, "resources/UCSC_HG19_Feb_2009/hg19.fa.fai")

  message("plotMAF() ...")
  if (is.na(samp) | is.null(dd[[samp]])) { ### samp = PATIENT
    stop("Please provide a sample label (or one that exists in the data)!")
  }

  message("Reading patient information: ", sQuote(convFILE))
  assertFile(convFILE)
  conv <- read.table(convFILE, header = TRUE, sep = "\t", as.is = TRUE)
  types <- conv$sample_type[which(conv$patient_ID == samp)] ### ie normal, primary, etc
  count <- length(types)

  pad <- 1000000 ## divide positions by 10^6 so that x-axis is in Mb

  ## pull data for the sample of interest
  d <- dd[[samp]]

  ## standardize chromosome notation (1-24, no "chr")
  d$chromosome <- gsub("chr", "", d$chromosome)
  d$chromosome[d$chromosome == "X"] <- 23
  d$chromosome[d$chromosome == "Y"] <- 24
  d$chromosome <- as.numeric(as.vector(d$chromosome))
  d <- d[order(d$chromosome, d$position), ]
  if (!is.numeric(ch)) {
    ch <- gsub("chr", "", ch)
    ch <- ifelse(ch == "X", 23, ch)
    ch <- ifelse(ch == "Y", 24, ch)
  }

  ## define some stuff
  isGenome <- FALSE

  ## plot the whole genome
  if (is.na(ch)) {
    # Plot the whole genome
    idx <- list()
    for (i in 1:count) {
      idx[[i]] <- which(d$samp == types[i])
    }
    isGenome <- TRUE
    if (!file.exists(pathnameFAI)) {
      stop("Full genome data requires an indexed FASTA (faidx) file for the genome in question")
    }
    ### haven't gone through the code below this...
    assertFile(pathnameFAI)
    hg <- read.table(pathnameFAI, header = FALSE, as.is = TRUE)[, 1:2]
    hg <- cbind(hg, cumsum(hg[, 2] / pad))
    colnames(hg) <- c("chrom", "pos", "absPos")
    hg <- hg[unique(d$chromosome), ]
    incr <- c(rep(0, times = sum(d$chromosome == 1)), hg$absPos[d$chromosome[d$chromosome > 1] - 1])
    d$absPos <- (d$position / pad) + incr

    ## plot a single chromosome
  } else {
    if (sum(d$chromosome == ch) == 0) {
      cat("No data on your chromosome of interest!")
      return()
    }

    idx <- list()
    for (i in 1:count) {
      idx[[i]] <- which(d$chromosome == ch & d$samp == types[i])
    }
    d$absPos <- d$position / pad ## convert to megabase positions (rather than bp)
  }

  ## graphing - set up the plot
  pch <- ifelse(isGenome, ".", 20) ## set parameters differently if graphing full genome or single chromosome
  cex <- ifelse(isGenome, 1, 0.5) ## ditto
  xlim <- c(0, max(d$absPos[unlist(idx)])) ## set appropriate x-axis limit, based on max position
  ylim <- c(-5, 50)
  lab <- paste(samp, ", chr", ch, sep = "")

  if (grid & !isGenome) {
    griddim <- c(3, ceiling((count - 1) / 3))
    par(mfrow = griddim, oma = c(1, 1, 2, 1), mai = c(rep(0.25, times = 4L)))
    col <- brewer.pal(count, "Set3")
    cex.text <- 0.75
    cex.pts <- 0.75
    for (i in 2:count) {
      plot(0, 0, type = "n", xlim = xlim, ylim = ylim, xlab = "", ylab = "", axes = FALSE)
      points(d$absPos[idx[[1]]], d$MAF[idx[[1]]], pch = pch, cex = cex, col = col[1]) ## plot normal
      points(d$absPos[idx[[i]]], d$MAF[idx[[i]]], pch = pch, cex = cex, col = col[i]) ## plot sample
      legend("bottomleft", c(types[1], types[i]), cex = cex.text, pt.cex = cex.pts, pch = pch, col = col[c(1, i)])
      if (!isGenome && (length(pos) > 1 || !is.na(pos))) {
        abline(v = pos / 1000000, col = "black", lwd = 2)
        if (!is.na(gene[1])) {
          for (i in 1:length(pos)) {
            text(pos[i] / 10^6, 0, gene[i], pos = 4, col = "black", cex = cex)
          }
        }
      }
      ## label y-axis
      axis(2, las = 2, at = seq(0, 50, by = 10), cex.axis = 0.8)
      ## label x-axis for chromosome-only plots
      if (!isGenome) {
        xlim <- round(xlim)
        xs <- seq(xlim[1], xlim[2], length.out = 6L)
        axis(1, at = xs, cex.axis = 0.8)
      }
    }
    mtext(text = lab, outer = TRUE, line = 1, side = 3)
  } else {
    plot(0, 0, type = "n", xlim = xlim, ylim = ylim, main = lab, xlab = "Genomic position (Mb)", ylab = "Minor Allele Frequency", axes = FALSE)
    ## genome-wide specific labeling
    if (isGenome) {
      # Plot chromosome markers legibility
      for (i in seq(2, nrow(hg), by = 2)) {
        x <- c(ifelse(i == 1, 0, hg$absPos[i - 1]), hg$absPos[i])
        polygon(c(x[1], x[1], x[2], x[2]), c(ylim[1], ylim[2], ylim[2], ylim[1]), col = "gray89", border = "gray89")
      }
      text(hg$absPos - (hg$pos / pad) / 2, -3, 1:24, cex = 0.5)
    }
    ## plot the data!
    col <- brewer.pal(count, "Set3")
    # col=brewer.pal(count, "Set2")
    # col=c("dodgerblue", "forestgreen", "goldenrod", "purple", "red")
    for (i in 1:count) {
      points(d$absPos[idx[[i]]], d$MAF[idx[[i]]], pch = pch, cex = cex, col = col[i])
    }
    # set appropriate scales for legend
    if (isGenome) {
      cex.text <- 0.75
      cex.pts <- 5
    }
    else {
      cex.text <- 0.75
      cex.pts <- 0.75
    }
    legend("bottomleft", types, cex = cex.text, pt.cex = cex.pts, pch = pch, col = col[1:count])
    if (!isGenome && (length(pos) > 1 || !is.na(pos))) {
      abline(v = pos / 1000000, col = "black", lwd = 2)
      if (!is.na(gene[1])) {
        for (i in 1:length(pos)) {
          text(pos[i] / 10^6, 0, gene[i], pos = 4, col = "black", cex = cex)
        }
      }
    }
    ## label y-axis
    axis(2, las = 2, at = seq(0, 50, by = 10), cex.axis = 0.8)
    ## label x-axis for chromosome-only plots
    if (!isGenome) {
      xlim <- round(xlim)
      xs <- seq(xlim[1], xlim[2], length.out = 6L)
      axis(1, at = xs, cex.axis = 0.8)
    }
  }
  message("plotMAF() ... DONE")
}
