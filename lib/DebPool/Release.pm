package DebPool::Release;

###
#
# DebPool::Release - Module for generating and installing Release files
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
# $Id: Release.pm 27 2004-11-07 03:06:59Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

use POSIX; # strftime
use File::Temp qw(tempfile);

# We need the Digest modules so that we can calculate the proper checksums.

use Digest::MD5;
use Digest::SHA;

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
        &Generate_Release_Triple
        &Install_Release
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Generate_Release_Triple &Install_Release)],
        'vars' => [qw()],
    );
}

### Exported package globals

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

# Magic filenames - these are files we want to include hashes for in a
# Release file.

my(@SigFiles) = (
    'Packages',
    'Sources',
    'Packages.gz',
    'Sources.gz',
    'Packages.bz2',
    'Sources.bz2',
);

### File lexicals

# None

### Constant functions

# None

### Meaningful functions

# Generate_Release_Triple($archive, $component, $architecture, $version)
#
# Generate a Release file for a specific dist/component/arch, in the
# temp/working area, and return the filename.
#
# Returns undef (and sets $Error) on error.

sub Generate_Release_Triple {
    use DebPool::Config qw(:vars);
    use DebPool::Dirs qw(:functions);

    my($archive, $component, $architecture, $version) = @_;

    my(@Checksums);

    # Before we bother to do much else, generate the MD5 and SHA1 checksums
    # we'll need later. This is mostly so that we can catch errors before
    # ever bothering to open a tempfile.

    # First, grab a list of files from the directory.

    my($dirpath) = "${Options{'dists_dir'}}/";
    $dirpath .= Archfile($archive, $component, $architecture, 1);

    if (!opendir(RELDIR, $dirpath)) {
        $Error = "Couldn't open directory '$dirpath'.";
        return;
    }

    my(@dirfiles) = readdir(RELDIR);
    close(RELDIR);

    # Now, for each file, generate MD5 and SHA1 checksums, and put them
    # into Checksums for later use (assuming it's a file we care about).

    foreach my $ck_file (@dirfiles) {
        if (0 == grep(/^$ck_file$/, @SigFiles)) { # We don't care about it.
            next;
        }

        # Grab the filesize from stat()

        my(@stat) = stat("${dirpath}/${ck_file}");
        my($size) = $stat[7];

        # Open the file and read in the contents. This could be a very
        # large amount of data, but unfortunately, both Digest routines
        # require the entire thing at once.

        if (!open($ck_fh, '<', "${dirpath}/${ck_file}")) {
            $Error = "Couldn't open file '${dirpath}/${ck_file}' for reading.";
            return;
        }

        my(@filetext) = <$ck_fh>;
        close($ck_fh);

        # Now calculate the checksums and put them into the hashes.

        my($md5) = Digest::MD5::md5_hex(@filetext);
        my($sha1) = Digest::SHA::sha1_hex(@filetext);
        my($sha256) = Digest::SHA::sha256_hex(@filetext);

        push @Checksums, {
            'File' => $ck_file,
            'Size' => $size,
            'MD5' => $md5,
            'SHA1' => $sha1,
            'SHA256' => $sha256,
        };
    }

    # Open a secure tempfile, and write the headers to it.

    my($tmpfile_handle, $tmpfile_name) = tempfile();

    print $tmpfile_handle "Archive: $archive\n";
    print $tmpfile_handle "Component: $component\n";
    print $tmpfile_handle "Version: $version\n";
    print $tmpfile_handle "Origin: $Options{'release_origin'}\n";
    print $tmpfile_handle "Label: $Options{'release_label'}\n";
    print $tmpfile_handle "Architecture: $architecture\n";

    # If the archive (aka distribution) appears in release_noauto, print
    # the appropriate directive.

    if (0 != grep(/^$archive$/, @{$Options{'release_noauto'}})) {
        print $tmpfile_handle "NotAutomatic: yes\n";
    }

    print $tmpfile_handle "Description: $Options{'release_description'}\n";

    # Now print MD5 and SHA1 checksum lists.

    print $tmpfile_handle "MD5Sum:\n";
    foreach my $checksum (@Checksums) {
        printf $tmpfile_handle " %s %8d %s\n", $checksum->{'MD5'},
            $checksum->{'Size'}, $checksum->{'File'};
    }

    print $tmpfile_handle "SHA1:\n";
    foreach my $checksum (@Checksums) {
        printf $tmpfile_handle " %s %8d %s\n", $checksum->{'SHA1'},
            $checksum->{'Size'}, $checksum->{'File'};
    }

    print $tmpfile_handle "SHA256:\n";
    foreach my $checksum (@Checksums) {
        printf $tmpfile_handle " %s %8d %s\n", $checksum->{'SHA256'},
            $checksum->{'Size'}, $checksum->{'File'};
    }

    close($tmpfile_handle);

    return $tmpfile_name;
}

# Generate_Release_Dist($archive, $version, @files)
#
# Generate top-level Release file for a specific distribution, covering the
# given files, in the temp/working area, and return the filename.
#
# Filenames in @files should be relative to <dists_dir>/<archive>, with no
# leading slash (ie, main/binary-i386/Packages).
#
# Returns undef (and sets $Error) on error.

sub Generate_Release_Dist {
    use DebPool::Config qw(:vars);

    my($archive) = shift(@_);
    my($version) = shift(@_);
    my(@files) = @_;

    my(@Checksums);
    my($dists_dir) = $Options{'dists_dir'};

    # Before we bother to do much else, generate the MD5 and SHA1 checksums
    # we'll need later. This is mostly so that we can catch errors before
    # ever bothering to open a tempfile.

    for my $file (@files) {
        my($fullfile) = "${dists_dir}/${archive}/${file}";

        # Now, for each file, generate MD5 and SHA1 checksums, and put them
        # into Checksums for later use (assuming it's a file we care about).
    
        my(@stat) = stat($fullfile);
        my($size) = $stat[7];
    
        if (!open($hash_fh, '<', $fullfile)) {
            $Error = "Couldn't open file '${fullfile} for reading.";
            return;
        }
        my(@filetext) = <$hash_fh>;
        close($hash_fh);

        # Now calculate the checksums and put them into the hashes.
    
        my($md5) = Digest::MD5::md5_hex(@filetext);
        my($sha1) = Digest::SHA::sha1_hex(@filetext);
        my($sha256) = Digest::SHA::sha256_hex(@filetext);
    
        push @Checksums, {
            'File' => $file,
            'Size' => $size,
            'MD5' => $md5,
            'SHA1' => $sha1,
            'SHA256' => $sha256,
        };
    }

    # Open a secure tempfile, and set up some variables.

    my($tmpfile_handle, $tmpfile_name) = tempfile();

    my($now_822) = strftime('%a, %d %b %Y %H:%M:%S %Z', localtime());
    my(@archs) = grep(!/^source$/, @{$Options{'archs'}});
    my($suite) = $Options{'reverse_dists'}->{$archive};

    # Write the headers into the Release tempfile

    print $tmpfile_handle "Origin: ${Options{'release_origin'}}\n";
    print $tmpfile_handle "Label: ${Options{'release_label'}}\n";
    print $tmpfile_handle "Suite: ${suite}\n";
    print $tmpfile_handle "Codename: ${archive}\n";
    print $tmpfile_handle "Date: ${now_822}\n";
    print $tmpfile_handle "Architectures: " . join(' ', @archs) . "\n";
    print $tmpfile_handle "Components: " . join(' ', @{$Options{'sections'}}) . "\n";
    print $tmpfile_handle "Description: $Options{'release_description'}\n";

    # Now print MD5 and SHA1 checksum lists.

    print $tmpfile_handle "MD5Sum:\n";
    foreach my $file (@Checksums) {
        printf $tmpfile_handle " %s %8d %s\n", $file->{'MD5'},
            $file->{'Size'}, $file->{'File'};
    }

    print $tmpfile_handle "SHA1:\n";
    foreach my $file (@Checksums) {
        printf $tmpfile_handle " %s %8d %s\n", $file->{'SHA1'},
            $file->{'Size'}, $file->{'File'};
    }

    print $tmpfile_handle "SHA256:\n";
    foreach my $file (@Checksums) {
        printf $tmpfile_handle " %s %8d %s\n", $file->{'SHA256'},
            $file->{'Size'}, $file->{'File'};
    }

    close($tmpfile_handle);

    return $tmpfile_name;
}

# Install_Release($archive, $component, $architecture, $release, $signature)
#
# Installs a release file and an optional signature file to the
# distribution directory specified by the ($archive, $component,
# $architecture) triple, or $archive if $component and $architecture are
# undefined. Returns 0 (and sets $Error) on failure, 1 on
# success.

sub Install_Release {
    use DebPool::Config qw(:vars);
    use DebPool::Util qw(:functions);

    my($archive, $component, $architecture, $release, $signature) = @_;

    my($dists_file_mode) = $Options{'dists_file_mode'};

    my($inst_dir);
    if (defined($architecture) && defined($component)) {
        $inst_dir = "${Options{'dists_dir'}}/";
        $inst_dir .= Archfile($archive, $component, $architecture, 1);
    } else {
        $inst_dir = "${Options{'dists_dir'}}/${archive}";
    }

    # Now install the file(s) into the appropriate place(s).

    if (!Move_File($release, "${inst_dir}/Release", $dists_file_mode)) {
        $Error = "Couldn't install Release file '${release}' to ";
        $Error .= "'${inst_dir}': ${DebPool::Util::Error}";
        return 0;
    }

    if (defined($signature) && !Move_File($signature, "${inst_dir}/Release.gpg",
            $dists_file_mode)) {
        $Error = "Couldn't install Signature file '${signature}' to ";
        $Error .= "'${inst_dir}': ${DebPool::Util::Error}";
        return 0;
    }

    return 1;
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
