package DebPool::Dirs;

###
#
# DebPool::Dirs - Module for dealing with directory related tasks
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
# $Id: Dirs.pm 71 2006-06-26 21:16:01Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

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
        &Archfile
        &Create_Tree
        &Tree_Mkdir
        &Setup_Incoming_Watch
        &Monitor_Incoming
        &PoolBasePath
        &PoolDir
        &Scan_Changes
        &Scan_All
        &Strip_Subsection
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Archfile &Create_Tree &Tree_Mkdir
                           &Monitor_Incoming &Setup_Incoming_Watch
                           &PoolBasePath &PoolDir &Scan_Changes &Scan_All
                           &Strip_Subsection)],
        'vars' => [qw()],
    );
}

### Exported package globals

# None

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

my($inotify);

### File lexicals

# None

### Constant functions

# None

### Meaningful functions

# Create_Tree()
#
# Creates a full directory tree based on the current directory values in
# %DebPool::Config::Options. Returns 1 on success, 0 on failure (and sets
# or propagates $Error).

sub Create_Tree {
    use DebPool::Config qw(:vars);

    # Basic directories - none of these are terribly exciting. We don't set
    # $Error on failure, because Tree_Mkdir will have already done so.

    if (!Tree_Mkdir($Options{'db_dir'}, $Options{'db_dir_mode'})) {
        return 0;
    }

    if (!Tree_Mkdir($Options{'incoming_dir'}, $Options{'incoming_dir_mode'})) {
        return 0;
    }

    if (!Tree_Mkdir($Options{'installed_dir'}, $Options{'installed_dir_mode'})) {
        return 0;
    }

    if (!Tree_Mkdir($Options{'reject_dir'}, $Options{'reject_dir_mode'})) {
        return 0;
    }

    # Now the distribution directory and subdirectories

    my($dists_dir) = $Options{'dists_dir'};
    my($dists_dir_mode) = $Options{'dists_dir_mode'};

    if (!Tree_Mkdir($dists_dir, $dists_dir_mode)) {
        return 0;
    }

    # Real distributions are the only ones that get directories.

    my($dist);
    foreach $dist (@{$Options{'realdists'}}) {
        if (!Tree_Mkdir("$dists_dir/$dist", $dists_dir_mode)) {
            return 0;
        }

        my($section);
        foreach $section (@{$Options{'sections'}}) {
            if (!Tree_Mkdir("$dists_dir/$dist/$section", $dists_dir_mode)) {
                return 0;
            }

            my($arch);
            foreach $arch (@{$Options{'archs'}}) {
                my($target) = "$dists_dir/$dist/$section/";
                if ('source' eq $arch) {
                    $target .= $arch;
                } else {
                    $target .= "binary-$arch";
                }

                if (!Tree_Mkdir($target, $dists_dir_mode)) {
                    return 0;
                }
            }
        }
    }

    # Go through all of the distributions looking for those that should be
    # symlinks, and creating them if necessary.

    foreach $dist (keys(%{$Options{'dists'}})) {
        # Check whether it should be a symlink. If so, make sure it is.

        if (!($dist eq $Options{'dists'}->{$dist})) { # Different names -> sym
            if (! -e "$dists_dir/$dist") {
                if (!symlink($Options{'dists'}->{$dist}, "$dists_dir/$dist")) {
                    $Error = "Couldn't create symlink $dists_dir/$dist -> ";
                    $Error .= "$Options{'dists'}->{$dist}: $!";
                }
            } elsif (! -l "$dists_dir/$dist") {
                $Error = "$dists_dir/$dist exists and isn't a symlink, ";
                $Error .= "but it should be";
                return 0;
            }
        }
    }

    # And, finally, the pool directories and their subdirectories

    my($pool_dir) = $Options{'pool_dir'};
    my($pool_dir_mode) = $Options{'pool_dir_mode'};

    if (!Tree_Mkdir($pool_dir, $pool_dir_mode)) {
        return 0;
    }

    # We can only get away with this because Debian pool directories are
    # named in ASCII...

    my($section);
    foreach $section (@{$Options{'sections'}}) {
        next if $section =~ m/\s*\/debian-installer/;
        if (!Tree_Mkdir("$pool_dir/$section", $pool_dir_mode)) {
            return 0;
        }
    }

    return 1;
}

# Tree_Mkdir($directory, $mode)
#
# Creates $directory with $mode. Returns 0 and sets $Error on failure, or
# 1 on success.

sub Tree_Mkdir {
    my($dir, $mode) = @_;

    if (-d $dir) {
        return 1;
    };

    if (-e $dir) {
        $Error = "Couldn't create '$dir' - already exists as a non-directory.";
        return 0;
    }

    if (!mkdir($dir, $mode)) {
        $Error = "Couldn't create '$dir': $!";
        return 0;
    }

    if (!chmod($mode, $dir)) {
        $Error = "Couldn't chmod '$dir': $!";
        return 0;
    }

    return 1;
}

# Scan_Changes($directory)
#
# Scan the specified directory for changes files. Returns an array of
# filenames relative to the directory, or undef (and sets $Error) on an error.

sub Scan_Changes {
    my($directory) = @_;

    if (!opendir(INCOMING, $directory)) {
        $Error = "Couldn't open directory '$directory': $!";
        return undef;
    }

    # Perl magic - read the directory and grep it for *.changes all at one
    # shot.

    my(@changes) = grep(/\.changes$/, readdir(INCOMING));
    close(INCOMING);

    return @changes;
}

# Scan_All($directory)
#
# Scans the specified directory and all subdirectories for any files.
# Returns an arrayref pointing to an array of filepaths relative to
# $directory, or undef (and sets $Error) on failure. Ignores any hidden
# files or directories.

sub Scan_All {
    my($directory) = @_;

    if (!opendir(DIR, $directory)) {
        $Error = "Couldn't open directory '$directory'";
        return undef;
    }

    my($direntry);
    my(@entries) = grep(!/^\./, readdir(DIR));

    my(@return);

    foreach $direntry (@entries) {
        if (-f "$directory/$direntry") {
            push(@return, $direntry);
        } elsif (-d "$directory/$direntry") {
            my($recurse) = Scan_All("$directory/$direntry");

            if (!defined($recurse)) { # $Error is already set.
                return undef;
            }

            # I'd like to use map(), but Perl makes stooopid guesses.

            my($entry);

            foreach $entry (@{$recurse}) {
                push(@return, "$direntry/$entry");
            }
        }
    }

    return \@return;
}

# Setup_Incoming_Watch()
#
# Creates a Linux::Inotify2 object and adds a watch on the incoming directory.
# Returns 1 on success, 0 on failure (and sets $Error).

sub Setup_Incoming_Watch {
    use DebPool::Logging qw(:functions :facility :level);
    use DebPool::Config;
    if (!eval{ require Linux::Inotify2; }) {
        Log_Message("liblinux-inotify2-perl is required to activate inotify support for debpool.", LOG_GENERAL, LOG_WARNING);
        return 0;
    } else {
        use Linux::Inotify2;
    }

    $inotify = new Linux::Inotify2;
    if (!$inotify) {
        $Error = "Unable to create new inotify object: $!";
        Log_Message("$Error", LOG_GENERAL, LOG_ERROR);
        return 0;
    }
    if (!$inotify->watch("$Options{'incoming_dir'}",
                         IN_CLOSE_WRITE |
                         IN_MOVED_TO )) {
        $Error = "Unable to watch $Options{'incoming_dir'}: $!";
        Log_Message("$Error", LOG_GENERAL, LOG_ERROR);
        return 0;
    }
    Log_Message("Watching $Options{'incoming_dir'} with Inotify",
                LOG_GENERAL, LOG_DEBUG);
    return 1;
}

# Watch_Incoming()
#
# Reads events from the Inotify2 object (blocking until one occurs),
# picks out the .changes file(s) and returns them (if any; otherwise
# it loops).
#
# Returns a list of .changes files on success, undef on failure (which
# includes interruption by a signal).
    
sub Watch_Incoming {
    use DebPool::Logging qw(:functions :facility :level);

    while (my @events = $inotify->read) {
	my @changes;
	foreach (@events) {
	    push @changes, $_->name if ($_->name =~ /\.changes$/);
	}
        if (@changes > 0) {
            Log_Message("Found changes: ".join(', ', @changes),
                        LOG_GENERAL, LOG_DEBUG);
            return @changes;
        }
    }
    return undef;
}

# Monitor_Incoming()
#
# Monitors the incoming directory, looping until the directory is updated.
# Returns a list of .changes files on success, undef on failure (which
# includes interruption by a signal - check $DebPool::Signal::Signal_Caught).

sub Monitor_Incoming {
    use DebPool::Config;
    use DebPool::Logging qw(:functions :facility :level);

    # If this is ever false, we either shouldn't have been called in the
    # first place, or we've caught a signal and shouldn't do anything
    # further.

    if ($DebPool::Signal::Signal_Caught) {
        return undef;
    }

    if ($Options{'use_inotify'}) {
        return Watch_Incoming();
    } else {
        my(@stat) = stat($Options{'incoming_dir'});
        my($mtime) = $stat[9];

        do {
            Log_Message("Incoming monitor: sleeping for " .
                        $Options{'sleep'} . " seconds", LOG_GENERAL, LOG_DEBUG);
            sleep($Options{'sleep'});
            @stat = stat($Options{'incoming_dir'});
            if (!@stat) {
                $Error = "Couldn't stat incoming_dir '$Options{'incoming_dir'}'";
                return undef;
            }
            return undef if $DebPool::Signal::Signal_Caught;
        } until ($stat[9] != $mtime);
        
        return Scan_Changes();
    }
}

# PoolDir($name, $section, $archive_base)
#
# Calculates a pool subdirectory name from the package name and the section
# (if provided; assumed to be 'main' if undefined or unrecognized).

sub PoolDir {
    my($name, $section, $archive_base) = @_;

    $section = Strip_Subsection($section);

    # Pool subdirectories are normally the first letter of the package
    # name, unless it is a lib* package, in which case the subdir is
    # lib<first letter>.

    if ($name =~ s/^lib//) { # lib(.).*
        return $section . '/' . 'lib' . substr($name, 0, 1);
    } else { # (.).*
        return $section . '/' . substr($name, 0, 1);
    }
}

# Strip_Subsection($section)
#
# This routine could, perhaps, better named. However, the purpose is to
# take a Section header as found in a package, and return the 'section'
# (rather than [section/]subsection) of it - that is, 'main', 'contrib', or
# 'non-free' (normally; it uses the configuration options to track this).
#
# Any unrecognized section is assumed to be 'main'; section values without
# *any* subsection portion succeed, as well (at least, assuming that they
# are otherwise valid).

sub Strip_Subsection {
    use DebPool::Config qw(:vars);

    my($section) = @_;

    if (!defined($section)) {
        return 'main';
    }
    
    my($check_section);
    foreach $check_section (@{$Options{'sections'}}) {
        if ($section =~ m/^$check_section(\/.+)?$/) {
            return $check_section;
        }
    }

    return 'main';
}

# PoolBasePath()
#
# Calculates the value of the relative path from archive_dir to pool_dir
# (this is primarily useful when having to provide file paths relative to
# archive_dir, such as in Packages/Sources files). This does assume that
# pool_dir is a subdirectory of archive_dir, but if that isn't true then
# things are royally screwed up *anyway*...

sub PoolBasePath {
    use DebPool::Config qw(:vars);

    my($path) = $Options{'pool_dir'};
    $path =~ s/^$Options{'archive_dir'}\///;
    return $path;
}

# Archfile($archive, $component, $architecture, $dironly)
#
# Returns the file name for the Packages/Sources file, or the directory
# name of the arch directory if $dironly is true, (from a base of
# dists_dir) for the specified archive, component, and architecture.

sub Archfile {
    my($archive) = shift(@_);
    my($component) = shift(@_);
    my($architecture) = shift(@_);
    my($dironly) = shift(@_);

    my($result) = "$archive/$component";

    my($type);
    if ('source' eq $architecture) {
        $result .= "/${architecture}";
        $type = "Sources";
    } else {
        $result .= "/binary-${architecture}";
        $type = "Packages";
    }
    
    if (!$dironly) {
        $result .= "/${type}";
    }

    return $result;
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
