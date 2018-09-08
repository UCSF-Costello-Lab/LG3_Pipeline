# LG3_Pipeline

## Version 2018-09-08-9000 (development version)

* ...


## Version 2018-09-08

* DOCUMENTATION:

  - Add "how-to-run" instructions to README.


* SOFTWARE QUALITY:

  - All PBS (\*.pbs) and Bash scripts (scripts/\*.sh) now pass [ShellCheck]
    tests.  Significant changes involve quoting command-line options, adding
    assertions that `cd` and `mkdir` actual works.

  - Add `make check` to check scripts with ShellCheck.

  - The code is now continuously validated using the [Travis CI] service.


* BUG FIXES:

  - Several Bash scripts/\*.sh had `#!/bin/csh` shebangs.



[ShellCheck]: https://github.com/koalaman/shellcheck
[Travis CI]: https://travis-ci.org/UCSF-Costello-Lab/LG3_Pipeline
