package DebPool::DB;

###
#
# DebPool::DB - Module for managing data hashes via tied NDBM files
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
# $Id: DB.pm 62 2005-02-23 18:02:38Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

# This module mostly wraps calls to tied NDBM hashes, so we need these.

use Fcntl;
use NDBM_File;

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
        %ComponentDB
        &Open_Databases
        &Close_Databases
        &Get_Version
        &Set_Versions
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Open_Databases &Close_Databases &Get_Version
                           &Set_Versions)],
        'vars' => [qw(%ComponentDB)],
    );
}

### Exported package globals

# I'd love to be able to do this as a hash of hashes of hashrefs, but the
# database layer can't handle it. So we have multiple DBs.

# VersionDB - hash of tied hashes, keyed on Distribution (then Source
# package). Keeps track of all versions. Prior to 0.2.2, the value pointed
# to was a scalar representing the version of the source package; as of
# 0.2.2 and later, updated records are hashrefs pointing to hashes that
# have package -> version mappings, with 'source' being the key for source
# package version.

our(%VersionDB);

# ComponentDB - hash of tied hashes, keyed on Distribution (then Source
# package). Stores the component data for the given package.

our(%ComponentDB);

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

### File lexicals

# None

### Constant functions

# None

### Meaningful functions

# Open_Databases()
#
# Open all tied NDBM hashes for each real distribution. Returns 0 in the
# case of errors opening hashes, 1 otherwise.

sub Open_Databases {
    use DebPool::Config qw(:vars);

    my($db_dir) = $Options{'db_dir'};
    my($db_file_mode) = $Options{'db_file_mode'};
    my($dist);

    foreach $dist (@{$Options{'realdists'}}) {
        my(%tiedhash);
        my($tie_result) = tie(%tiedhash, 'NDBM_File',
                              "$db_dir/${dist}_version",
                              O_RDWR|O_CREAT, $db_file_mode);
        if (!defined($tie_result)) {
            return 0;
        };

        $VersionDB{$dist} = \%tiedhash;
    }

    foreach $dist (@{$Options{'realdists'}}) {
        my(%tiedhash);
        my($tie_result) = tie(%tiedhash, 'NDBM_File',
                              "$db_dir/${dist}_component",
                              O_RDWR|O_CREAT, $db_file_mode);
        if (!defined($tie_result)) {
            return 0;
        };

        $ComponentDB{$dist} = \%tiedhash;
    }

    return 1;
}

# Close_Databases()
#
# Closes all tied NDBM hashes.
#
# NOTE: Untie doesn't return anything (?), so we can't really trap errors.

sub Close_Databases {
    my($dist);

    foreach $dist (keys(%VersionDB)) {
        untie(%{$VersionDB{$dist}});
    }

    foreach $dist (keys(%ComponentDB)) {
        untie(%{$ComponentDB{$dist}});
    }

    return 1;
}

# Get_Version($dist, $source, $package)
#
# Retrieves the version of $package (from source package $source) in
# distribution $dist. The package name 'source' retrieves the source
# package name, or undef if no information is available.

sub Get_Version {
    my($dist, $source, $package) = @_;

    my($temp) = $VersionDB{$dist}->{$source};
    if (!defined($temp)) { return undef; }

    # Versions prior to 0.2.2 had only one entry, which is the source
    # version; since this is the same as the binary version on the vast
    # majority of packages, fake an answer. This works because hash entries
    # are guaranteed to be non-empty.

    if ($temp !~ m/\|/) {
        return $temp;
    }

    if ('meta' eq $package) {
        $temp =~ s/\|.*//;
        return $temp;
    } elsif ('source' eq $package) {
        return $VersionDB{$dist}->{"source_${source}"};
    } else {
        return $VersionDB{$dist}->{"binary_${source}_${package}"};
    }
}

# Set_Versions($dist, $source, $file_arrayref

sub Set_Versions {
    my($dist, $source, $meta_version, $file_arrayref) = @_;

    my($oldbinlist) = $VersionDB{$dist}->{$source};
    if (defined($oldbinlist) && ($oldbinlist =~ m/\|/)) { # 0.2.2 or later
        $oldbinlist =~ s/.*\|//; # Strip meta version
        my(@oldbins) = split(/,/,$oldbinlist);

        my($oldbin);
        foreach $oldbin (@oldbins) {
            $VersionDB{$dist}->{"binary_${source}_${oldbin}"} = undef;
        }

        $VersionDB{$dist}->{"source_${source}"} = undef;
        $VersionDB{$dist}->{"${source}"} = undef;
    }

    # Walk through each file looking for version data. Note that only the
    # .dsc file is guaranteed to be the same for source uploads (it can be
    # orig.tar.gz or tar.gz, and diff.gz need not exist), and .deb files
    # have binary versions, so that's all we look for.
    #
    # FIXME: Do udeb files have different versions from deb files?

    my(@files) = @{$file_arrayref};
    my(@entries) = ();

    my($hashref);
    foreach $hashref (@files) {
        my($filename) = $hashref->{'Filename'};

        if ($filename =~ m/^([^_]+)_([^_]+)_.+\.deb/) {
            my($package) = $1;
            my($version) = $2;

            $VersionDB{$dist}->{"binary_${source}_${package}"} = $version;
            push(@entries, $package);
        } elsif ($filename =~ m/^[^_]+_([^_]+)\.dsc/) {
            my($version) = $1;

            $VersionDB{$dist}->{"source_${source}"} = $version;
            push(@entries, 'source');
        } # else skip
    }

    $VersionDB{$dist}->{$source} = "${meta_version}|" . join(',', @entries);
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
