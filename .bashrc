# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# User specific aliases and functions

shopt -s huponexit
ulimit -s unlimited


#===============
#export PATH="$HOME/.rbenv/bin:$PATH"
#eval "$(rbenv init -)"
#. /bivonalab/conf/taylorlab.sh

export RHOME=/home/shared/cbc/software_cbc/R/R-3.4.4-20180315
export R_LIBS=/home/jocostello/R/x86_64-pc-linux-gnu-library/3.4
#export R_LIBS="/home/jocostello/R"
export PATH=$PATH:/home/ismirnov/ibin:/home/jocostello/ibin:.
#module load CBC cbc-shared
module load CBC shellcheck

alias x='exit'
alias sc='shellcheck'
alias scx='shellcheck -x'
alias lh='ls -lt | head -n 20'
alias +x='chmod u+x'
alias qstati='qstat -n -u ismirnov'
alias qstatj='qstat -n -u jocostello'
alias gg='ssh ivan@costellolab.ucsf.edu'
alias bk='ssh ismirnov@costello-bu1'

