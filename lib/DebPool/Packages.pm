package DebPool::Packages;

###
#
# DebPool::Packages - Module for handling package metadata
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
# $Id: Packages.pm 70 2006-06-26 20:44:57Z joel $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

use POSIX; # WEXITSTATUS
use File::Temp qw(tempfile tempdir);

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
        &Allow_Version
        &Audit_Package
        &Generate_List
        &Generate_Package
        &Generate_Source
        &Guess_Section
        &Install_List
        &Install_Package
        &Reject_Package
        &Verify_MD5
        &Strip_Epoch
        &Get_Package_Files
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Allow_Version &Audit_Package &Generate_List
                        &Generate_Package &Generate_Source &Guess_Section
                        &Install_List &Install_Package &Reject_Package
                        &Verify_MD5 &Strip_Epoch &Get_Package_Files)],
        'vars' => [qw()],
    );
}

### Exported package globals

# None

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our $Error;

### File lexicals

# None

### Constant functions

# None

### Our necessary DebPool Modules

use DebPool::Config qw(:vars);
use DebPool::DB qw(:functions :vars);
use DebPool::Logging qw(:functions :facility :level);
use DebPool::Dpkg qw(:functions);
use DebPool::Dirs qw(:functions);
use DebPool::Parser qw(:functions);
use DebPool::Util qw(:functions);

### Meaningful functions

# Allow_Version($package, $version, $distribution, $arch)
# Parameter data types (string, string, string, array_ref)
#
# Decide, based on version comparison and config options, whether $version
# is an acceptable version for $package in $distribution. Returns 1 if the
# version is acceptable, 0 if it is not, and undef (and sets $Error) in the
# case of an error.

sub Allow_Version {
    my($package, $version, $distribution, $arch) = @_;

    my $old_version = Get_Version($distribution, $package, 'meta');

    # If we permit rollback, any version is valid.

    if ($Options{'rollback'}) {
        return 1;
    }

    # If we don't have an old version, anything is acceptable.

    if (!defined($old_version)) {
        return 1;
    }

    if ($version eq $old_version) {
        my (%count, @duplicate_arches);
        my @old_archs = Get_Archs($distribution, $package);
        foreach (@old_archs, @{$arch}) {
            if (++$count{$_} > 1) {
                push @duplicate_arches, $_;
            }
        }
        if (@duplicate_arches) {
            my $msg = "Version comparison for '$package': ";
            $msg .= "proposed version for $distribution ($version) ";
            $msg .= "is same as current version and the following ";
            $msg .= "architectures already exist: ";
            $msg .= join ', ', @duplicate_arches;
            Log_Message($msg, LOG_GENERAL, LOG_DEBUG);
            return 0;
        }
        return 1;
    }

    if (!Dpkg_Compare_Versions($version, 'gt', $old_version)) {
        # DPKG says no go.
        my $msg = "Version comparison for '$package': proposed version for ";
        $msg .= "$distribution ($version) is not greater than current ";
        $msg .= "version ($old_version)";
        Log_Message($msg, LOG_GENERAL, LOG_DEBUG);

        return 0;
    }

    return 1;
}

# Generate_List($distribution, $section, $arch)
#
# Generates a Packages (or Sources) file for the given distribution,
# section, and architecture (with 'source' being a special value for
# Sources). Returns the filename of the generated file on success, or undef
# (and sets $Error) on failure. Note that requests for an 'all' list are
# ignored - however, every non-source arch gets 'all' files.

sub Generate_List {
    my($distribution, $section, $arch) = @_;

    if ('all' eq $arch) {
        $Error = "No point in generating Packages file for binary-all";
        return;
    }

    my @sources = grep($ComponentDB{$distribution}->{$_} eq $section,
                        keys(%{$ComponentDB{$distribution}}));

    my($tmpfile_handle, $tmpfile_name) = tempfile();

    # Dump the data from pool/*/*/pkg_ver.{package,source} into the list.

    # FIXME: This needs to be refactored. Needs it pretty badly, in fact.

    if ('source' eq $arch) {
        foreach my $source (@sources) {
            my $pool = join('/',
                ($Options{'pool_dir'}, PoolDir($source, $section), $source));
            my $version = Get_Version($distribution, $source, 'meta');
            my $target = "$pool/${source}_" . Strip_Epoch($version);
            $target .= '.source';

            # Source files aren't always present.
            next if (!open(my $src_fh, '<', "$target"));

            $tmpfile_handle->print(<$src_fh>);
            close($src_fh);
        }
    } else {
        foreach my $source (@sources) {
            my $pool = join('/',
                ($Options{'pool_dir'}, PoolDir($source, $section), $source));
            my $version = Get_Version($distribution, $source, 'meta');

            my $archpackagefiles =
                Get_Package_Files($source, $version, $section, $arch);
            my $archallpackagefiles =
                Get_Package_Files($source, $version, $section, 'all');

            my $target = @{$archpackagefiles}[0];
            my $target_all = @{$archallpackagefiles}[0];

            my ($pkg_arch_fh, $pkg_all_fh);

            # Check for any binary-arch packages
            if (($target) and (-e $target)) {
                if (!open($pkg_arch_fh, '<', "$target")) {
                    my $msg = "Skipping package entry for all packages from ";
                    $msg .=
                        "${source}: couldn't open '$target' for reading: $!";

                    Log_Message($msg, LOG_GENERAL, LOG_ERROR);
                    next;
                }
            }

            # Check for any binary-all packages
            if (($target_all) and (-e $target_all)) {
                if (!open($pkg_all_fh, '<', "$target_all")) {
                    my $msg = "Skipping package entry for all packages ";
                    $msg .= "from ${source}: couldn't open '$target_all' for";
                    $msg .= " reading: $!";

                    Log_Message($msg, LOG_GENERAL, LOG_ERROR);
                    next;
                }
            }

            # Playing around with the record separator ($/) to make this
            # easier.

            my $backup_RS = $/;
            $/ = "";

            my @arch_entries;
            if (-e $target) { # Write entries from arch packages
                @arch_entries = <$pkg_arch_fh>;
                close($pkg_arch_fh);
            }

            my @all_entries;
            if (($target_all) and (-e $target_all)) {
                # Write entries from all packages
                @all_entries = <$pkg_all_fh>;
                close($pkg_all_fh);
            }

            $/ = $backup_RS;

            # Pare it down to the relevant entries, and print those out.

            @arch_entries = grep(/\nArchitecture: ($arch)\n/, @arch_entries);
            @all_entries = grep(/\nArchitecture: all\n/, @all_entries);
            print $tmpfile_handle @arch_entries;
            print $tmpfile_handle @all_entries;
        }
    }

    close($tmpfile_handle);

    return $tmpfile_name;
}

# Install_Package($changes, $dsc, $distributions, $changes_data, $dsc_data)
# Parameter data types (string, string, array_ref, hash_ref, hash_ref)
#
# Install all of the package files for $changes_data into the pool directory,
# and install the file in $changes to the installed directory. Also generates
# (and installs) .package and .source meta-data files. It also updates the
# Version database for the listed distributions. Returns 1 if successful, 0
# if not (and sets $Error).

sub Install_Package {
    my($changes, $dsc, $distributions, $changes_data, $dsc_data) = @_;

    my $incoming_dir = $Options{'incoming_dir'};
    my $installed_dir = $Options{'installed_dir'};
    my $pool_dir = $Options{'pool_dir'};

    my $pkg_name = $changes_data->{'Source'};

    my $pkg_ver = $changes_data->{'Version'};
    my $source_version = $changes_data->{'Source-Version'};

    my $guess_section = Guess_Section($changes_data);
    my $pkg_pool_subdir = join('/',
        ($pool_dir, PoolDir($pkg_name, $guess_section)));
    my $pkg_dir = join('/', ($pkg_pool_subdir, $pkg_name));

    # Create the directory or error out

    if (!Tree_Mkdir($pkg_pool_subdir, $Options{'pool_dir_mode'})) {
        return 0;
    }
    if (!Tree_Mkdir($pkg_dir, $Options{'pool_dir_mode'})) {
        return 0;
    }

    # Walk the File Hash, trying to install each listed file into the
    # pool directory.

    foreach my $file (keys %{$changes_data->{'Files'}}) {
        if (!Move_File("${incoming_dir}/${file}", "${pkg_dir}/${file}",
                $Options{'pool_file_mode'})) {
            $Error = "Failed to move '${incoming_dir}/${file}' ";
            $Error .= "to '${pkg_dir}/${file}': ${DebPool::Util::Error}";
            return 0;
        }
    }

    # Generate and install .package and .source metadata files.

    my @pkg_archs = @{$changes_data->{'Architecture'}};
    @pkg_archs = grep(!/source/, @pkg_archs); # Source is on it's own.

    my $target;
    foreach my $pkg_arch (@pkg_archs) {
        my $pkg_file = Generate_Package($changes_data, $pkg_arch);

        if (!defined($pkg_file)) {
            $Error = "Failed to generate .package file: $Error";
            return;
        }

        $target = "$pkg_dir/${pkg_name}_" . Strip_Epoch($pkg_ver) .
            "_$pkg_arch" . '.package';

        if (!Move_File($pkg_file, $target, $Options{'pool_file_mode'})) {
            $Error = "Failed to move '$pkg_file' to '$target': ";
            $Error .= $DebPool::Util::Error;
            return 0;
        }
    }

    if ($dsc and $dsc_data) {
        my $src_file = Generate_Source($dsc, $dsc_data, $changes_data);

        if (!defined($src_file)) {
            $Error = "Failed to generate .source file: $Error";
            return;
        }

        $target = "$pkg_dir/${pkg_name}_" . Strip_Epoch($pkg_ver) . '.source';

        if (!Move_File($src_file, $target, $Options{'pool_file_mode'})) {
            $Error = "Failed to move '$src_file' to '$target': ";
            $Error .= $DebPool::Util::Error;
            return 0;
        }
    }

    # Finally, try to install the changes file to the installed directory.

    if (!Move_File("$incoming_dir/$changes", "$installed_dir/$changes",
            $Options{'installed_file_mode'})) {
        $Error = "Failed to move '$incoming_dir/$changes' to ";
        $Error .= "'$installed_dir/$changes': ${DebPool::Util::Error}";
        return 0;
    }

    # Update the various databases.
    my $section = Guess_Section($changes_data);
    my $component = Strip_Subsection($section);
    foreach my $distribution (@{$distributions}) {
        Set_Versions($distribution, $pkg_name, $pkg_ver,
            $changes_data->{'Files'});
        $ComponentDB{$distribution}->{$pkg_name} = $component;
    }
    if ( $section eq 'debian-installer' ) {
        $component .= '/debian-installer';
    }

    return 1;
}

# Reject_Package($changes, $changes_data)
# Parameter data types (string, hash_ref)
#
# Move all of the package files for $changes_data (which should be a
# Parse_Changes result hash) into the rejected directory, as well as the
# file in $changes. Returns 1 if successful, 0 if not (and sets $Error).

sub Reject_Package {
    my($changes, $changes_data) = @_;

    my $incoming_dir = $Options{'incoming_dir'};
    my $reject_dir = $Options{'reject_dir'};
    my $reject_file_mode = $Options{'reject_file_mode'};

    # Walk the File Hash, moving each file to the rejected directory.

    foreach my $file (keys %{$changes_data->{'Files'}}) {
        if (!Move_File("$incoming_dir/$file", "$reject_dir/$file",
                $reject_file_mode)) {
            $Error = "Failed to move '$incoming_dir/$file' ";
            $Error .= "to '$reject_dir/$file': ${DebPool::Util::Error}";
            return 0;
        }
    }

    # Now move the changes file to the rejected directory, as well.

    if (!Move_File("$incoming_dir/$changes", "$reject_dir/$changes",
            $reject_file_mode)) {
        $Error = "Failed to move '$incoming_dir/$changes' to ";
        $Error .= "'$reject_dir/$changes': ${DebPool::Util::Error}";
        return 0;
    }

    return 1;
}

# Verify_MD5($file, $md5)
#
# Verifies the MD5 checksum of $file against $md5. Returns 1 if it matches,
# 0 if it doesn't, and undef (also setting $Error) if an error occurs.

sub Verify_MD5 {
    my($file, $md5) = @_;

    # Read in and mangle the md5 output.

    if (! -r $file) { # The file doesn't exist! Will be hard to checksum it...
        my $msg = "MD5 checksum unavailable: file '$file' does not exist!";
        Log_Message($msg, LOG_GENERAL, LOG_ERROR);
        return 0;
    }

    my $cmd_result = `/usr/bin/md5sum $file`;
    if (!$cmd_result) { # Failed to run md5sum for some reason
        my $msg = "MD5 checksum unavailable: file '$file'";
        Log_Message($msg, LOG_GENERAL, LOG_ERROR);
        return 0;
    }

    $cmd_result =~ m/^([[:xdigit:]]+)\s+/;
    my $check_md5 = $1;

    if ($md5 ne $check_md5) {
        my $msg = "MD5 checksum failure: file '$file', ";
        $msg .= "expected '$md5', got '$check_md5'";
        Log_Message($msg, LOG_GENERAL, LOG_ERROR);
        return 0;
    }

    return 1;
}

# Audit_Package($package, $changes_data)
# Parameter data types (string, hash_ref)
#
# Delete a package and changes files for the named (source) package which
# are not referenced by any version currently found in the various release
# databases. Returns the number of files unlinked (which may be 0), or
# undef (and sets $Error) on an error.

sub Audit_Package {
    my($package, $changefile, $changes_data) = @_;

    # Checking for version of package being installed
    my $changes_version = $changes_data->{'Version'};

    my $installed_dir = $Options{'installed_dir'};
    my $pool_dir = $Options{'pool_dir'};

    my $section = Guess_Section($changes_data);
    my $package_dir = join('/',
        ($pool_dir, PoolDir($package, $section), $package));

    my @changes = grep(/${package}_/, Scan_Changes($installed_dir));
    my @changes_arch = @{$changes_data->{'Architecture'}};

    my $pool_scan = Scan_All($package_dir);
    if (!defined($pool_scan)) {
        $Error = $DebPool::Dirs::Error;
        return;
    }
    my @pool_files = @{$pool_scan};

    # Go through each file found in the pool directory, and determine its
    # version. If it isn't in the current version tables, unlink it.

    my $unlinked = 0;
    foreach my $file (@pool_files) {
        # Go through each architecture in the changes file
        foreach my $arch (@changes_arch) {
            my $orig = 0;
            my $deb = 0;
            my $src = 0;
            my $bin_package = 0;
            my $version = 0;
            if ($arch eq 'source') {
                if ($file =~ m/^([^_]+)_([^_]+)\.orig\.tar\.gz$/) { #orig.tar.gz
                    $bin_package = $1;
                    $version = $2;
                    $src = 1;
                    $orig = 1;
                } elsif ($file =~ m/^([^_]+)_([^_]+)\.tar\.gz$/) { # tar.gz
                    $bin_package = $1;
                    $version = $2;
                    $src = 1;
                } elsif ($file =~ m/^([^_]+)_([^_]+)\.diff\.gz$/) { # diff.gz
                    $bin_package = $1;
                    $version = $2;
                    $src = 1;
                } elsif ($file =~ m/^([^_]+)_([^_]+)\.dsc$/) { # dsc
                    $bin_package = $1;
                    $version = $2;
                    $src = 1;
                } elsif ($file =~ m/^([^_]+)_([^_]+)\.source$/) {
                    # source metadata
                    $bin_package = $1;
                    $version = $2;
                }
            } else {
                if ($file =~
                    m/^([^_]+)_([^_]+)\Q_${arch}.\Eu?deb$/) { # deb or udeb
                    $bin_package = $1;
                    $version = $2;
                    $deb = 1;
                } elsif ($file =~
                    m/^([^_]+)_([^_]+)\Q_${arch}.\Epackage$/) {
                    # package metadata
                    $bin_package = $1;
                    $version = $2;
                }
            }
            # Skip the file if it comes from a different architecture.
            next if $bin_package eq 0;

            # Skip files if we recognize it as a valid version.
            my $matched = 0;
            foreach my $dist (@{$Options{'realdists'}}) {
                my $ver_pkg;
                if ($src) {
                    $ver_pkg = 'source';
                } elsif ($deb) {
                    $ver_pkg = $bin_package;
                } else {
                    $ver_pkg = 'meta';
                }

                my $dist_ver = Get_Version($dist, $package, $ver_pkg);
                next if (!defined($dist_ver)); # No version in specified dist
                $dist_ver = Strip_Epoch($dist_ver);
                if ($orig) { $dist_ver =~ s/-.+$//; }
                if ($version eq $dist_ver) { $matched = 1; }
            }
            next if $matched;

            # Otherwise, unlink it.

            if (unlink("$package_dir/$file")) {
                $unlinked += 1;
                Log_Message("Unlinked obsolete pool file '$package_dir/$file'",
                    LOG_AUDIT, LOG_DEBUG);
            } else {
                Log_Message("Couldn't obsolete pool file '$package_dir/$file'",
                    LOG_AUDIT, LOG_ERROR);
            }
        }
    }

    # Now we want to do the same for the changes files.
    # First, we'll want to include the architecture the changes file was
    # generated from. This is in case that package builds only architecture
    # independent packages, such as debpool.
    my $changefile_arch = $changefile;
    $changefile_arch =~ s/^[^_]+_[^_]+_([^.]+)\.changes$/$1/;
    if (!grep {$_ eq $changefile_arch} @changes_arch) {
        push @changes_arch, $changefile_arch;
    }
    foreach my $file (@changes) {
        foreach my $arch (@changes_arch) {
            my $version = 0;
            if ($file =~ m/^[^_]+_([^_]+)\Q_${arch}.\Echanges$/) { # changes
                $version = $1;
            }
            next if $version eq 0;

            my $matched = 0;
            foreach my $dist (@{$Options{'realdists'}}) {
                my $dist_ver = Get_Version($dist, $package, 'meta');
                next if (!defined($dist_ver)); # No version in specified dist
                $dist_ver = Strip_Epoch($dist_ver);
                if ($version eq $dist_ver) { $matched = 1; }
            }
            next if $matched;

            if (unlink("$installed_dir/$file")) {
                $unlinked += 1;
                Log_Message("Unlinked obsolete changes file " .
                    "'$installed_dir/$file'", LOG_AUDIT, LOG_DEBUG);
            } else {
                Log_Message("Couldn't obsolete changes file " .
                    "'$installed_dir/$file'", LOG_AUDIT, LOG_ERROR);
            }
        }
    }

    return $unlinked;
}

# Generate_Package($changes_data, $arch)
# Parameter data types (hash_ref, string)
#
# Generates a .package metadata file (Packages entries for each binary
# package) in the tempfile area, and returns the filename. Returns undef
# (and sets $Error) on failure.

sub Generate_Package {
    my($changes_data, $arch) = @_;

    my $source = $changes_data->{'Source'};
    my $source_version = $changes_data->{'Source-Version'};

    my @packages = (grep(/u?deb$/, (keys %{$changes_data->{'Files'}})));
    my $pool_base = PoolBasePath();

    # Grab a temporary file.
    my($tmpfile_handle, $tmpfile_name) = tempfile();

    foreach my $package (@packages) {
        my $section = Guess_Section($changes_data);
        my $pool = join('/', (PoolDir($source, $section), $source));

        # Run DpkgDeb_Control() to extract the control file from the deb
        # archive. Then parse the control file.
        my $tmpdir = tempdir(CLEANUP => 1);
        if (!DpkgDeb_Control("$Options{'pool_dir'}/$pool/$package", $tmpdir)) {
            my $msg = "Could not extract control file from deb file ";
            $msg .= "$Options{'pool_dir'}/$pool/$package";
            Log_Message($msg, LOG_GENERAL, LOG_ERROR);
            return;
        }
        my $control = Parse_File("$tmpdir/control");

        # Dump all of our data into the metadata tempfile.
        print $tmpfile_handle "Package: $package\n";

        if (defined($control->{'Priority'})) {
            print $tmpfile_handle "Priority: $control->{'Priority'}\n";
        }

        if (defined($control->{'Section'})) {
            print $tmpfile_handle "Section: $control->{'Section'}\n";
        }

        if (defined($control->{'Essential'})) {
            print $tmpfile_handle "Essential: $control->{'Essential'}\n";
        }

        print $tmpfile_handle "Installed-Size: $control->{'Installed-Size'}\n";

        print $tmpfile_handle "Maintainer: $changes_data->{'Maintainer'}\n";
        print $tmpfile_handle "Architecture: $arch\n";
        if ($source_version) {
            print $tmpfile_handle "Source: $source ($source_version)\n";
        } else {
            print $tmpfile_handle "Source: $source\n";
        }
        print $tmpfile_handle "Version: $changes_data->{'Version'}\n";

        # All of the inter-package relationships go together, and any
        # one of them can potentially be empty (and omitted).
        my @Relationship_Fields = ('Pre-Depends', 'Depends', 'Provides',
            'Conflicts', 'Recommends', 'Suggests', 'Enhances', 'Replaces',);
        foreach my $field (@Relationship_Fields) {
            if (defined($control->{$field})) {
                print $tmpfile_handle "${field}: " .
                    join(', ', @{$control->{$field}}) . "\n";
            }
        }

        # Some stuff we can grab out of the parsed changes data far more easily
        # than anywhere else.
        print $tmpfile_handle "Filename: $pool_base/$pool/$package\n";
        print $tmpfile_handle "Size: " .
            $changes_data->{'Files'}{$package}[1] . "\n";
        print $tmpfile_handle "MD5sum: " .
            $changes_data->{'Files'}{$package}[0] . "\n";
        print $tmpfile_handle "SHA1: " .
            $changes_data->{'Checksums-Sha1'}{$package}[0] . "\n";
        print $tmpfile_handle "SHA256: " .
            $changes_data->{'Checksums-Sha256'}{$package}[0] . "\n";

        # Our description and homepage from the package's control file.
        print $tmpfile_handle "Description: ";
        foreach my $tmp (@{$control->{'Description'}}) {
            print $tmpfile_handle "$tmp\n";
        }
        if (defined $control->{'Homepage'}) {
            print $tmpfile_handle "Homepage: $control->{'Homepage'}\n";
        }

        print $tmpfile_handle "\n";
    }

    # All done
    close($tmpfile_handle);
    return $tmpfile_name;
}

# Generate_Source($dsc, $dsc_data, $changes_data)
# Parameter data types (string, hash_ref, hash_ref)
#
# Generates a .source metadata file (Sources entries for the source
# package) in the tempfile area, and returns the filename. Returns undef
# (and sets $Error) on failure.

sub Generate_Source {
    my($dsc, $dsc_data, $changes_data) = @_;

    my $source = $dsc_data->{'Source'};
    my $version = $dsc_data->{'Version'};
    my $source_version = $changes_data->{'Source-Version'}; # if binNMU
    my @files = (keys %{$dsc_data->{'Files'}});
    my @checksums_sha1 = (keys %{$dsc_data->{'Checksums-Sha1'}});
    my @checksums_sha256 = (keys %{$dsc_data->{'Checksums-Sha256'}});

    # Figure out the priority and section, using the DSC filename and
    # the Changes file data. We also determine the pool path here.
    my ($section, $priority, $poolpath);
    foreach my $filehr (grep(/^$dsc$/,(keys %{$changes_data->{'Files'}}))) {
        $section = $changes_data->{'Files'}{$filehr}[2];
        $priority = $changes_data->{'Files'}{$filehr}[3];
        $poolpath = join('/',
            (PoolBasePath(), PoolDir($source, $section), $source));
    }

    # If we don't have a section or priority at this point, it probably means
    # we're doing a binary only upload. Thus we determine the pool path using
    # the section from one of the binary packages. We then parse a .source file
    # that should already be in the pool area and grab the section and priority
    # from this file.
    if ((!$section) or (!$priority)) {
            foreach my $filehr (keys %{$changes_data->{'Files'}}) {
            my $tmpsection = $changes_data->{'Files'}{$filehr}[2];
            $poolpath = join('/',
                (PoolBasePath(), PoolDir($source, $tmpsection), $source));
            my $poolfullpath = "$Options{'archive_dir'}/$poolpath";
            my $sourcedata;
            my $pattern = "$poolfullpath/$source" . "_" .
                Strip_Epoch($source_version);
            my @testlist = grep(/^\Q$pattern\E(\+b\d+|)\.source$/,
                glob($poolfullpath . '/*'));
            foreach my $tmp (grep(/^\Q$pattern\E(\+b\d+|)\.source$/,
                glob($poolfullpath . '/*'))) {
                $sourcedata =
                    Parse_File($tmp);
                last if ($sourcedata);
            }
            $section = $sourcedata->{'Section'};
            $priority = $sourcedata->{'Priority'};
            last if (($section) and ($priority));
        }
    }

    # Grab a temporary file.
    my($tmpfile_handle, $tmpfile_name) = tempfile();

    # Dump out various metadata.
    print $tmpfile_handle "Package: $source\n";
    print $tmpfile_handle
        "Binary: " . join(', ', @{$dsc_data->{'Binary'}}) . "\n";
    print $tmpfile_handle "Version: $version\n";
    print $tmpfile_handle "Priority: $priority\n";
    print $tmpfile_handle "Section: $section\n";
    print $tmpfile_handle "Maintainer: $dsc_data->{'Maintainer'}\n";

    if (defined($dsc_data->{'Build-Depends'})) {
        print $tmpfile_handle 'Build-Depends: ';
        print $tmpfile_handle
            join(', ', @{$dsc_data->{'Build-Depends'}}) . "\n";
    }

    if (defined($dsc_data->{'Build-Depends-Indep'})) {
        print $tmpfile_handle 'Build-Depends-Indep: ';
        print $tmpfile_handle
            join(', ', @{$dsc_data->{'Build-Depends-Indep'}}) . "\n";
    }

    print $tmpfile_handle 'Architecture: ';
    print $tmpfile_handle join(' ', @{$dsc_data->{'Architecture'}}) . "\n";

    print $tmpfile_handle
        "Standards-Version: $dsc_data->{'Standards-Version'}\n"
        if exists $dsc_data->{'Standards-Version'};
    print $tmpfile_handle "Format: $dsc_data->{'Format'}\n";
    print $tmpfile_handle "Directory: $poolpath/$source\n";

    print $tmpfile_handle "Files:\n";
    foreach my $fileref (@files) {
        print $tmpfile_handle " " . $dsc_data->{'Files'}{$fileref}[0];
        print $tmpfile_handle " " . $dsc_data->{'Files'}{$fileref}[1];
        print $tmpfile_handle " $fileref\n";
    }

    if (defined $dsc_data->{'Uploaders'}) {
        print $tmpfile_handle "Uploaders: ";
        print $tmpfile_handle join(', ', @{$dsc_data->{'Uploaders'}}) . "\n";
    }

    if (defined $dsc_data->{'Dm-Upload-Allowed'}) {
        print $tmpfile_handle "Dm-Upload-Allowed: " .
            $dsc_data->{'Dm-Upload-Allowed'} . "\n";
    }

    if (defined $dsc_data->{'Homepage'}) {
        print $tmpfile_handle "Homepage: $dsc_data->{'Homepage'}\n";
    }

    my @vcs = sort(grep(/^Vcs/, (keys %{$dsc_data})));
    foreach my $tmp (@vcs) {
        print $tmpfile_handle "$tmp: $dsc_data->{$tmp}\n";
    }

    print $tmpfile_handle "Checksums-Sha1: \n";
    foreach my $fileref (@checksums_sha1) {
        print $tmpfile_handle " " . $dsc_data->{'Checksums-Sha1'}{$fileref}[0];
        print $tmpfile_handle " " . $dsc_data->{'Checksums-Sha1'}{$fileref}[1];
        print $tmpfile_handle " $fileref\n";
    }

    print $tmpfile_handle "Checksums-Sha256: \n";
    foreach my $fileref (@checksums_sha256) {
        print $tmpfile_handle " " .
            $dsc_data->{'Checksums-Sha256'}{$fileref}[0];
        print $tmpfile_handle " " .
            $dsc_data->{'Checksums-Sha256'}{$fileref}[1];
        print $tmpfile_handle " $fileref\n";
    }

    print $tmpfile_handle "\n";

    # All done

    close($tmpfile_handle);
    return $tmpfile_name;
}

# Install_List($archive, $component, $architecture, $listfile, $zfiles)
# Parameter data types (string, string, string, string, array_ref)
#
# Installs a distribution list file (from Generate_List), along with an
# optional gzipped version of the same file (if $gzfile is defined).
# Returns 1 on success, or 0 (and sets $Error) on failure.

sub Install_List {
    my($archive, $component, $architecture, $listfile, $zfiles) = @_;

    my $dists_file_mode = $Options{'dists_file_mode'};
    my $inst_file = "$Options{'dists_dir'}/";
    $inst_file .= Archfile($archive, $component, $architecture, 0);

    # Now install the file(s) into the appropriate place(s).

    if (!Move_File($listfile, $inst_file, $dists_file_mode)) {
        $Error = "Couldn't install distribution file '$listfile' ";
        $Error .= "to '${inst_file}': ${DebPool::Util::Error}";
        return 0;
    }

    foreach my $zfile (@{$zfiles}) {
    my ($ext) = $zfile =~ m{\.([^/]+)$};
        if (!Move_File($zfile, "${inst_file}.${ext}",
                $dists_file_mode)) {
            $Error = "Couldn't install compressed distribution file '$zfile' ";
            $Error .= "to '${inst_file}.${ext}': ${DebPool::Util::Error}";
            return 0;
        }
    }

    return 1;
}

# Guess_Section($changes_data)
# Parameter data types (hash_ref)
#
# Attempt to guess the freeness section of a package based on the data
# for the first file listed in the changes.

sub Guess_Section {
    my($changes_data) = @_;

    # Pull out the primary section from the changes data. Note that this is
    # a cheap hack, but it is mostly used when needing the pool directory
    # section, which is based solely on freeness-sections (main, contrib,
    # non-free).
    my @changes_files = (keys %{$changes_data->{'Files'}});
    return $changes_data->{'Files'}{$changes_files[0]}[2];
}

# Strip_Epoch($version)
#
# Strips any epoch data off of the version.

sub Strip_Epoch {
    my($version) = @_;

    $version =~ s/^[^:]://;
    return $version;
}

# Package_Files($source, $version, $arch)
# Parameter data types (string, string, string)
#
# Finds the .package files in a pool area and returns an array ref with the
# list of .package files.

sub Get_Package_Files {
    my ($source, $version, $section, $arch) = @_;

    my $pool = join('/',
        ($Options{'pool_dir'}, PoolDir($source, $section), $source));
    my $tmpversion = Strip_Epoch($version);
    $tmpversion =~ s/(\+b\d+)$//; # in case of binary only uploads

    my $pattern = "$pool/" . "${source}_$tmpversion";
    my @packagefiles = grep(/^\Q${pattern}_$arch.package\E$/,
        glob($pool. '/*'));
    if (!@packagefiles) { # try looking for binary only uploads
        @packagefiles = grep(/^\Q$pattern\E(\+b\d+|)_$arch\.package$/,
            glob($pool. '/*'));
    }

    return \@packagefiles;
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
