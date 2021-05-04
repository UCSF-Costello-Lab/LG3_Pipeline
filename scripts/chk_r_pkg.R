### See https://github.com/broadinstitute/gatk/blob/master/scripts/docker/gatkbase/install_R_packages.R

is.installed <- function(mypkg) is.element(mypkg, installed.packages()[,1])

libs=c('getopt','optparse','gsalib','gplots','ggplot2','reshape2')
for (lib in libs) {
	if ( ! is.installed(lib) ) { cat(paste("ERROR: missing R library",lib,"\n")); quit(save="no", status=1) } 
}
quit(save="no", status=0)
