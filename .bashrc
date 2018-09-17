# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

shopt -s huponexit
ulimit -s unlimited

export RHOME=/home/shared/cbc/software_cbc/R/R-3.4.4-20180315
export R_LIBS=/home/jocostello/R/x86_64-pc-linux-gnu-library/3.4
export PATH=$PATH:/home/ismirnov/ibin:/home/jocostello/ibin:.
