package DebPool::Logging;

###
#
# DebPool::Logging - Module to handle logging messages
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
# $Id: Logging.pm 31 2005-01-19 17:32:38Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

# For strftime()

use POSIX;

# We need to pull config option information

use DebPool::Config qw(:vars);
use DebPool::DB qw(:functions); # DB::Close_Databases

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
        &Log_Message
        &LOG_AUDIT
        &LOG_CONFIG
        &LOG_DEBUG
        &LOG_ERROR
        &LOG_FATAL
        &LOG_GENERAL
        &LOG_GPG
        &LOG_INFO
        &LOG_INSTALL
        &LOG_PARSE
        &LOG_REJECT
        &LOG_WARNING
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Log_Message)],
        'vars' => [qw()],
        'facility' => [qw(&LOG_AUDIT &LOG_CONFIG &LOG_GENERAL &LOG_GPG
                          &LOG_INSTALL &LOG_PARSE &LOG_REJECT)],
        'level' => [qw(&LOG_DEBUG &LOG_INFO &LOG_WARNING &LOG_ERROR
                       &LOG_FATAL)],
    );
}

### Exported package globals

# None

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

### File lexicals

# None

### Constant functions - facility

sub LOG_AUDIT { 'AUDIT' }
sub LOG_CONFIG { 'CONFIG' }
sub LOG_GENERAL { 'GENERAL' }
sub LOG_GPG { 'GPG' }
sub LOG_INSTALL { 'INSTALL' }
sub LOG_REJECT { 'REJECT' }
sub LOG_PARSE { 'PARSE' }

### Constant functions - level

sub LOG_DEBUG { 'DEBUG' }
sub LOG_INFO { 'INFO' }
sub LOG_WARNING { 'WARNING' }
sub LOG_ERROR { 'ERROR' }
sub LOG_FATAL { 'FATAL' }

### Meaningful functions

# Log_Message($message, FACILITY, LEVEL)
#
# Log a message with text $message using FACILITY and LEVEL, via the current
# configured log method.

# FIXME - this is a really crude logging setup. We should probably support
# a variety of things, like logging to processes, syslogging, not doing an
# open/close for each message, maybe email logging with batched messages.
#
# However, this is an early version, so it will suffice for now.

sub Log_Message {
    my($msg, $facility, $level) = @_;

    # First, do we have anywhere to log? We assume that 'undef' is an
    # explicit request to not log, since it isn't a default value.

    if (!defined($Options{'log_file'})) {
        return;
    }

    # If we can't log to it, die with a message (on the off chance that we're
    # not in daemon mode, and the user will see it).

    my $log_fh;
    if (!open($log_fh, '>>', $Options{'log_file'})) {
        Close_Databases(); # If they were open
        unlink($Options{'lock_file'}); # In case we had one

        die "Couldn't write to log file '$Options{'log_file'}'.";
    }

    print $log_fh strftime("%Y-%m-%d %H:%M:%S", localtime());
    print $log_fh " [$facility/$level] $msg\n";
    close($log_fh);
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
