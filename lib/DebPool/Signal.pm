package DebPool::Signal;

###
#
# DebPool::DB - Module for handling inter-process signals
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
# $Id: Signal.pm 27 2004-11-07 03:06:59Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

# We do logging, so we need this.

use DebPool::Logging qw(:functions :facility :level);

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
        $Signal_Caught
        %ComponentDB
    );

    %EXPORT_TAGS = (
        'functions' => [qw()],
        'vars' => [qw($Signal_Caught)],
    );
}

### Exported package globals

# Boolean value indicating whether we have caught one of the signals that
# normally trigger clean termination (SIGHUP, SIGINT, SIGPIPE, SIGTERM).

our($Signal_Caught) = 0;

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

### File lexicals

# None

### Constant functions

# None

### Meaningful functions

# None

### Special

# The purpose of this module is to handle signals usefully; therefore, we
# set up a basic term-signal handler that catches the 'ordinary termination
# requested' class of signals, and bind it via sigtrap.

sub Handle_SIGtermrequest {
    my($signal) = shift(@_);

    $Signal_Caught = 1;
    Log_Message("Caught signal " . $signal, LOG_GENERAL, LOG_INFO);
}

sub Handle_SIGHUP {
    Handle_SIGtermrequest('SIGHUP');
}

use sigtrap qw(handler Handle_SIGHUP HUP);

sub Handle_SIGINT {
    Handle_SIGtermrequest('SIGINT');
}

use sigtrap qw(handler Handle_SIGINT INT);

sub Handle_SIGPIPE {
    Handle_SIGtermrequest('SIGPIPE');
}

use sigtrap qw(handler Handle_SIGPIPE PIPE);

sub Handle_SIGTERM {
    Handle_SIGtermrequest('SIGTERM');
}

use sigtrap qw(handler Handle_SIGTERM TERM);

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
