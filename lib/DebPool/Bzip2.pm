package DebPool::Bzip2;

###
#
# DebPool::Bzip2 - Module for handling Bzip2 interactions
#
# Copyright 2003-2004 Joel Aelwyn. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the Author nor the names of any contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $Id: Bzip2.pm 27 2004-11-07 03:06:59Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

use POSIX; # WEXITSTATUS

# Needed for open2()

use Fcntl;
use IPC::Open2;

### Module setup

BEGIN {
    use Exporter ();
    our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

    # Version checking
    $VERSION = '0.1.5';

    @ISA = qw(Exporter);

    @EXPORT = qw(
    );

    @EXPORT_OK = qw(
        &Bzip2_File
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Bzip2_File)],
        'vars' => [qw()],
    );
}

### Exported package globals

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

### File lexicals

# None

### Constant functions

# None

### Meaningful functions

# Bzip_File($file)
#
# Generates a bzipped version of $file, and returns the filename. Returns
# undef (and sets $Error) on failure.

sub Bzip2_File {
    use DebPool::Logging qw(:functions :facility :level);

    my($file) = @_;

    # Open a secure tempfile to write the compressed data into

    my($tmpfile) = new File::Temp( SUFFIX => '.bz2', UNLINK => 0 );

    # Open the source file so that we have it available.

    my $source_fh;
    if (!open($source_fh, '<', $file)) {
        $Error = "Couldn't open source file '$file': $!";
        return;
    }

    # We are go for main engine start

    my(@args) = ('--best', '--force', '--stdout');

    my($bzip2_pid) = open2(*BZIP2_IN, *BZIP2_OUT, '/bin/bzip2', @args);

    my($child_pid);
    if ($child_pid = fork) { # In the parent
        # Send all the data to Bzip2;

        close(BZIP2_IN);
        close($tmpfile);

        print BZIP2_OUT <$source_fh>;
        close(BZIP2_OUT);
        close($source_fh);

        waitpid($child_pid, 0);
        waitpid($bzip2_pid, 0);
    } else { # In the child - we hope
        if (!defined($child_pid)) {
            die "Couldn't fork: $!\n";
        }

        # Read back the results, and print them into the tempfile.

        close(BZIP2_OUT);
        close($source_fh);

        print $tmpfile <BZIP2_IN>;
        close(BZIP2_IN);
        close($tmpfile);

        exit(0);
    }

    # And we're done

    return $tmpfile->filename;
}

sub new {
    bless { ERROR => undef };
}

sub Compress_File {
    my $self = shift;
    my $tempname = Bzip2_File(@_);
    if ($tempname) {
	$self->{'ERROR'} = undef;
    }
    else {
	$self->{'ERROR'} = $Error;
    }
    $tempname;
}

sub Error {
    my $self = shift;
    $self->{'ERROR'};
}

sub Name {
    'bzip2';
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab: