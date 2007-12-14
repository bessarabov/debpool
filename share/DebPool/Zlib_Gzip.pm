package DebPool::Zlib_Gzip;

###
#
# DebPool::Zlib_Gzip - Module for handling Gzip interactions using
# Compress::Zlib
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
# $Id: Zlib_Gzip.pm 27 2004-11-07 03:06:59Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

use POSIX; # WEXITSTATUS

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
        &Gzip_File
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Gzip_File)],
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

# Gzip_File($file)
#
# Generates a gzipped version of $file using Compress::Zlib, and returns the
# filename. Returns undef (and sets $Error) on failure.

sub Gzip_File {
    use DebPool::Logging qw(:functions :facility :level);
    use Compress::Zlib;

    my($file) = @_;

    # Open a secure tempfile to write the compressed data into

    my($tmpfile) = new File::Temp( SUFFIX => '.gz' );
    my $gz = gzopen($tmpfile, 'wb9');
    if (!$gz) {
        $Error = "Couldn't initialize compression library: $gzerrno";
        return undef;
    }	

    # Open the source file so that we have it available.
    if (!open(SOURCE, '<', $file)) {
        $Error = "Couldn't open source file '$file': $!";
        return undef;
    }

    while (1) {
	my $buffer;
	my $bytesread = read SOURCE, $buffer, 4096;
	if (!defined $bytesread) {
	    $Error = "Error reading from '$file': $!";
	    close SOURCE;
	    return undef;
	}
	last if $bytesread == 0;
	my $byteswritten = $gz->gzwrite($buffer);
	if ($byteswritten < $bytesread) {
	    $Error = "Error gzwriting to temporary file: " . $gz->gzerror;
	    close SOURCE;
	    return undef;
	}
    }
    
    my $gzflush = $gz->gzflush(Z_FINISH);

    # zlib documentation says that Z_OK and Z_STREAM_END are ok
    if (($gzflush != Z_OK) && ($gzflush != Z_STREAM_END)) {
	$Error = "Error flushing compressed file: " . $gz->gzerror;
	print "$Error\n";
	close SOURCE;
	return undef;
    }

    # And we're done
    close SOURCE;
    $gz->gzclose;
    $tmpfile->unlink_on_destroy(0);
    return $tmpfile->filename;

}

sub new {
    bless { ERROR => undef };
}

sub Compress_File {
    my $self = shift;
    my $tempname = Gzip_File(@_);
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
    'gzip';
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
