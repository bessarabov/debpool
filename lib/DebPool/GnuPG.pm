package DebPool::GnuPG;

###
#
# DebPool::GnuPG - Module for all interactions with GNU Privacy Guard
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
# $Id: GnuPG.pm 46 2005-02-12 17:52:37Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

use 5.006_000;

# Always good ideas.

use strict;
use warnings;

use POSIX; # WEXITSTATUS
use File::Temp ();
use Fcntl; # for open3()
use IPC::Open3; # for open3()

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
        &Check_Signature
        &Sign_Release
        &Strip_GPG
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Check_Signature &Sign_Release &Strip_GPG)],
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

### Our necessary DebPool modules

use DebPool::Config qw(:vars);
use DebPool::Logging qw(:functions :facility :level);

### Meaningful functions

# Check_Signature($file, $signature)
#
# Checks the GPG signature of $file (using $signature as an external
# signature file, if it is defined; if it isn't, $file is assumed to have
# an internal signature). Returns 0 on failure, 1 on success.

sub Check_Signature {
    my($file, $signature) = @_;

    my(@args) = ('--verify', '--no-default-keyring');
    push(@args, '--homedir', $Options{'gpg_home'}) if defined
        $Options{'gpg_home'};

    foreach my $keyring (@{$Options{'gpg_keyrings'}}) {
        push(@args, '--keyring', $keyring);
    }

    # Always a good idea, even if we're pretty sure we won't get any file names
    # starting with "--" in this program.
    push(@args, '--');

    if (defined($signature)) {
        push(@args, $signature);
    }

    push(@args, $file);

    my($pid) = open3(*GPG_IN, *GPG_OUT, *GPG_OUT, $Options{'gpg_bin'}, @args);
    close(GPG_IN); # No input
    my @loglines = <GPG_OUT>;

    waitpid($pid,0); # No flags, just wait.

    if ($?) { # Failure
    foreach (@loglines) {
        Log_Message($_, LOG_GPG, LOG_DEBUG);
    }
        my($msg) = "Failed signature check on '$file' ";
        if (defined($signature)) {
            $msg .= "(signature file '$signature'): ";
        } else {
            $msg .= "(internal signature): ";
        }
    if (WIFEXITED($?)) {
        $msg .= "gpg returned non-zero status " . WEXITSTATUS($?);
    }
    elsif (WIFSIGNALED($?)) {
        $msg .= "gpg died from signal " . WTERMSIG($?);
    }
    else {
        $msg .= "gpg terminated in an unknown way.";
    }
        Log_Message($msg, LOG_GPG, LOG_WARNING);
    }
    return 1;
}

# Sign_Release($release_file)
#
# Generates a detached GPG signature file for $release_file, and returns
# the filename. Returns undef, if an error occurs (and sets $Error).

sub Sign_Release {
    my($release_file) = @_;

    # Open a secure tempfile to write the signature to

    my($tmpfile) = new File::Temp;

    # We are go for main engine start

    my(@args) =
        ('--batch', '--no-tty', '--detach-sign', '--armor', '--output=-');
    push(@args, '--homedir', $Options{'gpg_home'}) if defined
        $Options{'gpg_home'};
    push(@args, '--default-key', $Options{'gpg_sign_key'}) if defined
        $Options{'gpg_sign_key'};
    push(@args, '--passphrase-fd=0', '--passphrase-file',
        $Options{'gpg_passfile'}) if defined $Options{'gpg_passfile'};
    push(@args, '--', $release_file);

    my($gnupg_pid) = open3(*DUMMY, ">&".fileno $tmpfile, *GPG_ERR,
        $Options{'gpg_bin'}, @args);
    close DUMMY;
    my @loglines = <GPG_ERR>;
    waitpid($gnupg_pid, 0);

    foreach (@loglines) {
    Log_Message($_, LOG_GPG, $? ? LOG_ERROR : LOG_WARNING);
    }

    if ($?) {
    if (WIFEXITED($?)) {
        $Error = "gpg returned non-zero status " . WEXITSTATUS($?);
    }
    elsif (WIFSIGNALED($?)) {
        $Error = "gpg died from signal " . WTERMSIG($?);
    }
    else {
        $Error = "gpg terminated in an unknown way.";
    }
    return;
    }

    # And we're done
    $tmpfile->unlink_on_destroy(0);
    return $tmpfile->filename;
}

# Strip_GPG(@text)
#
# Goes through @text and determine if it has GnuPG headers; if so, strip
# out the headers, and undo GnuPG's header protection ('^-' -> '^-- -').

sub Strip_GPG {
    my(@text) = @_;

    my($header, $firstblank, $sigstart, $sigend);

    for my $count (0..$#text) {
        if ($text[$count] =~ m/^-----BEGIN PGP SIGNED MESSAGE-----$/) {
            $header = $count;
        } elsif (!defined($firstblank) && $text[$count] =~ m/^$/) {
            $firstblank = $count;
        } elsif ($text[$count] =~ m/^-----BEGIN PGP SIGNATURE-----$/) {
            $sigstart = $count;
        } elsif ($text[$count] =~ m/^-----END PGP SIGNATURE-----$/) {
            $sigend = $count;
        }
    }

    # If we didn't find all three parts, it isn't a validly signed message
    # (or it's externally signed, but that might as well be the same
    # thing for our purposes - there's nothing to remove).

    if (!defined($header) || !defined($sigstart) || !defined($sigend)) {
        return @text;
    }

    # Okay. Back to front, so that we don't muck up reference numbers.
    # First, we rip out the signature data by splicing it with an empty
    # list.

    splice(@text, $sigstart, ($sigend - $sigstart) + 1);

    # We used to just rip off the first 3 lines (BEGIN line, hash header,
    # and a blank line). However, this was a cheap shortcut that broke as
    # of GnuPG 1.0.7, because it relied on there being exactly one GnuPG
    # header line.
    #
    # Now, we rip out everything from the header line to the first blank,
    # which should always be correct.

    splice(@text, $header, ($firstblank - $header) + 1);

    # All done. Fire it back.

    return @text;
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
