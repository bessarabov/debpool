use 5.008_008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'DebPool',
    EXE_FILES         => [qw(bin/debpool)],
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (#ABSTRACT_FROM  => 'lib/DebPool.pm', # retrieve abstract from module
       AUTHOR         => 'DebPool Developers <debpool-devel@lists.alioth.debian.org>') : ()),
);
