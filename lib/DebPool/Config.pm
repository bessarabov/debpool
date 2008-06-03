package DebPool::Config;

###
#
# DebPool::Config - Module for handling config options
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
# $Id: Config.pm 38 2005-01-20 21:33:31Z joel $
#
###

=head1 NAME

DebPool::Config - configuration file format for debpool

=cut

=head1 SYNOPSIS

package DebPool::Config;

%Options = (
    'option1' => value1,
    'option2' => value2,
    ...
);

1;

=cut

=head1 DESCRIPTION

The DebPool::Config file is normally found in three places;
F</usr/share/debpool/Config.pm>, F</etc/debpool/Config.pm>, and
F<$HOME/.debpool/Config.pm> (in ascending order of precedence);
further locations can also be specified on the command line with the
'--config=<file>' option, which overrides all of these (and is, in turn,
overridden by any command line options). Also of note is the --nodefault
option, which prevents any attempt at loading the default (system and user)
config files.

The config files in /etc/debpool and $HOME/.debpool are not required to be
full Perl modules or to even exist. If they are used, they must still
declare a package namespace of 'DebPool::Config' and return a true value.

=cut

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
    	%Options
    	%OptionDefs
        &Clean_Options
        &Load_Default_Configs
        &Load_Minimal_Configs
        &Load_File_Configs
        &Override_Configs
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Clean_Options &Load_Default_Configs
                           &Load_Minimal_Configs &Load_File_Configs
                           &Override_Configs)],
        'vars' => [qw(%Options %OptionDefs)],
    );
}

### Exported package globals

# The core of everything this package is about.

our(%Options);
our(%OptionDefs);

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

### File lexicals

# None

### Constant functions

# None

### Module Init

# First things first - figure out how we need to be configured.

use Getopt::Long qw(:config pass_through);

# First, grab --config and --nodefault options if they exist. We
# don't want these in the %Options hash, and they affect what we do when
# loading it.

my @config_files;
my $default;

GetOptions('config=s' => \@config_files, 'default!' => \$default);

# Call Load_Default_Configs if we're loading default values, or
# Load_Minimal_Configs if we're not (we still need the OptionDefs hash to
# be populated).

if (!defined($default) || $default) {
    Load_Default_Configs();
} else {
    Load_Minimal_Configs();
}

# Load any config files we were given.

foreach my $config (@config_files) {
    Load_File_Configs($config);
}

# And finally, pull in any other command line options.

GetOptions(\%Options, values(%OptionDefs));

# Run the cleanup stuff on %Options.

Clean_Options();


### Meaningful functions

# Load_Default_Configs
#
# Loads the internal default values into %Options via
# Load_Internal_Configs, then 'require's config files from the default
# locations. It would be nice if we could log errors, but we can't safely
# load the logging module until we have all the configs in place. Catch-22.

sub Load_Default_Configs {
    Load_Internal_Configs();

    if (-r '/etc/debpool/Config.pm') {
        do '/etc/debpool/Config.pm'; # System defaults
    }

    if (-r "$ENV{'HOME'}/.debpool/Config.pm") {
        do "$ENV{'HOME'}/.debpool/Config.pm"; # User defaults
    }
}

# Load_Minimal_Configs
#
# Loads only the minimum configs necessary to be able to do parsing -
# that is, populate %OptionDefs. However, for sanity sake in documenting
# things, this has a side effect of also loading %Options, so we clear it
# afterwards.

sub Load_Minimal_Configs {
    Load_Internal_Configs();

    undef(%Options);
}

# Load_File_Configs($file)
#
# Loads configuration data from $file. We don't check for readability; if
# the user is insane enough to ask for a non-existant file, just die and
# tell them that they're stupid. Note: if this routine is called while a
# lockfile is held, it won't clean that up if we die.

sub Load_File_Configs {
    do "$_[0]";
}

# Override_Configs($override_hashref)
#
# Overrides current values in %Options (whatever those might be) with the
# values in the hash. Does not destroy unnamed values.

sub Override_Configs {
    my($hashref) = @_;

    foreach my $key (keys(%{$hashref})) {
        $Options{$key} = $hashref->{$key};
    }
}

# Clean_Options()
#
# Does some cleanup of $Options for sanity sake; also generates some
# auto-calculated values.

sub Clean_Options {
    # Clean up the architectures field; 'source' should always be present,
    # 'all' should never be. Simplest way to manage this is a throwaway
    # hash. This should maybe live somewhere else, but I'm not sure where.

    my %dummy;
    my @newarch;

    foreach my $dummykey (@{$Options{'archs'}}) {
        $dummy{$dummykey} = 1;
    }

    $dummy{'all'} = undef;
    $dummy{'source'} = 1;

    foreach my $dummykey (keys(%dummy)) {
        if ($dummy{$dummykey}) {
            push(@newarch, $dummykey);
        }
    }

    $Options{'archs'} = \@newarch;

    # Generate 'realdists' from %Options{'dists'} - these are the 'real'
    # (non-alias) distribution values.

    %dummy = ();
    
    foreach my $dummykey (values(%{$Options{'dists'}})) {
        $dummy{$dummykey} = 1;
    }

    my @realdists = keys(%dummy);
    $Options{'realdists'} = \@realdists;

    # Also generate a reverse-lookup table of real -> alias; in the case
    # of multiple aliases, the first one encountered wins (one of them has
    # to, and making it consistant and first means you can have multiple
    # aliases in a sensible order).

    my %reverse = ();
    foreach my $dummykey (keys(%{$Options{'dists'}})) {
        my $real = $Options{'dists'}->{$dummykey};
        if (!defined($reverse{$real})) {
            $reverse{$real} = $dummykey;
        }
    }

    $Options{'reverse_dists'} = \%reverse;

    # Enable releases if we have all of the pieces.
    if (defined($Options{'release_origin'})
    && defined($Options{'release_label'}) &&
    defined($Options{'release_description'})) { $Options{'do_release'} = 1;
    } else { $Options{'do_release'} = 0; }

    # If rebuild-all is present, turn on various rebuild options.

    if ($Options{'rebuild-all'}) {
        $Options{'rebuild-files'} = 1;
        $Options{'rebuild-dbs'} = 1;
    }
}

# Load_Internal_Configs()
#
# Loads %Options with basic default values.

sub Load_Internal_Configs {
=head1 OPTIONS

=head2 File/Directory configuration

These config values determine what directories various parts of the archive
are put in, and what permissions those directories have, as well as the
default permissions for files.

NOTE: While debpool will attempt to create db_dir, dists_dir, incoming_dir,
installed_dir, pool_dir, and reject_dir if they do not exist, it will *not*
attempt to do this for archive_dir.

WARNING: If you redefine archive_dir and you want the other four entries to
reflect this by incorporating the new value, you *MUST* redefine them here
(even if you simply use the default value of 'archive_dir'/<dirname>) so
that they use the new definition of archive_dir.

=over 4

=item B<archive_dir> => I<archive directory>

Base directory of the archive. This is never used directly; however, it
is normally used to construct relative paths for dists_dir, incoming_dir,
installed_dir, pool_dir, and reject_dir.

WARNING: See the section documentation for important details about
redefining this value.

Default value: '/var/cache/debpool'

=cut

$Options{'archive_dir'} = '/var/cache/debpool';
$OptionDefs{'archive_dir'} = 'archive_dir=s';

=item B<db_dir> => I<dists directory>

DB directory, where the database files for each distribution are kept.

Default value: "$Options{'archive_dir'}/db"

=cut

$Options{'db_dir'} = "$Options{'archive_dir'}/db";
$OptionDefs{'db_dir'} = 'db_dir=s';

=item B<db_dir_mode> = I<permissions (octal)>

Permissions for db_dir.

Default value: 0750

=cut

$Options{'db_dir_mode'} = 0750;
$OptionDefs{'db_dir_mode'} = 'db_dir_mode=i';

=item B<db_file_mode> = I<permissions (octal)>

Permissions for database files in db_dir.

Default value: 0640

=cut

$Options{'db_file_mode'} = 0640;
$OptionDefs{'db_file_mode'} = 'db_file_mode=i';

=item B<dists_dir> => I<dists directory>

Dists directory, where distribution files (F<{Packages,Sources}{,.gz}> live.

Default value: "$Options{'archive_dir'}/dists"

=cut

$Options{'dists_dir'} = "$Options{'archive_dir'}/dists";
$OptionDefs{'dists_dir'} = 'dists_dir=s';

=item B<dists_dir_mode> = I<permissions (octal)>

Permissions for dists_dir and all of it's subdirectories.

Default value: 0755

=cut

$Options{'dists_dir_mode'} = 0755;
$OptionDefs{'dists_dir_mode'} = 'dists_dir_mode=i';

=item B<dists_file_mode> = I<permissions (octal)>

Permissions for distribution files ({Packages,Sources}{,.gz}.

Default value: 0644

=cut

$Options{'dists_file_mode'} = 0644;
$OptionDefs{'dists_file_mode'} = 'dists_file_mode=i';

=item B<incoming_dir> => I<incoming directory>

Incoming directory, where new packages are uploaded.

Default value: "$Options{'archive_dir'}/incoming";

=cut

$Options{'incoming_dir'} = "$Options{'archive_dir'}/incoming";
$OptionDefs{'incoming_dir'} = 'incoming_dir=s';

=item B<incoming_dir_mode> = I<permissions (octal)>

Permissions for incoming_dir. Should have the sticky bit set if you want a
system archive.

Default value: 01775

=cut

$Options{'incoming_dir_mode'} = 01775;
$OptionDefs{'incoming_dir_mode'} = 'incoming_dir_mode=i';

=item B<installed_dir> => I<installed directory>

Incoming directory, where new packages are uploaded.

Default value: "$Options{'archive_dir'}/installed";

=cut

$Options{'installed_dir'} = "$Options{'archive_dir'}/installed";
$OptionDefs{'installed_dir'} = 'installed_dir=s';

=item B<installed_dir_mode> = I<permissions (octal)>

Permissions for installed_dir. Should have the sticky bit set if you want a
system archive.

Default value: 0755

=cut

$Options{'installed_dir_mode'} = 0755;
$OptionDefs{'installed_dir_mode'} = 'installed_dir_mode=i';

=item B<installed_file_mode> = I<permissions (octal)>

Permissions for installed Changes files.

Default value: 0644

=cut

$Options{'installed_file_mode'} = 0644;
$OptionDefs{'installed_file_mode'} = 'installed_file_mode=i';

=item B<pool_dir> => I<pool directory>

Pool directory where all .deb files are stored after being accepted. Normally
this is constructed as a relative path from archive_dir.

Default value: "$Options{'archive_dir'}/pool"

=cut

$Options{'pool_dir'} = "$Options{'archive_dir'}/pool";
$OptionDefs{'pool_dir'} = 'pool_dir=s';

=item B<pool_dir_mode> = I<permissions (octal)>

Permissions for pool_dir and all of it's subdirectories.

Default value: 0755

=cut

$Options{'pool_dir_mode'} = 0755;
$OptionDefs{'pool_dir_mode'} = 'pool_dir_mode=i';

=item B<pool_file_mode> = I<permissions (octal)>

Permissions for files installed into the pool area (orig.tar.gz, tar.gz,
diff.gz, dsc, deb).

Default value: 0644

=cut

$Options{'pool_file_mode'} = 0644;
$OptionDefs{'pool_file_mode'} = 'pool_file_mode=i';

=item B<reject_dir> => I<reject directory>

Reject directory, where rejected packages are placed.

Default value: "$Options{'archive_dir'}/reject"

=cut

$Options{'reject_dir'} = "$Options{'archive_dir'}/reject";
$OptionDefs{'reject_dir'} = 'reject_dir=s';

=item B<reject_dir_mode> = I<permissions (octal)>

Permissions for reject_dir.

Default value: 0750

=cut

$Options{'reject_dir_mode'} = 0750;
$OptionDefs{'reject_dir_mode'} = 'reject_dir_mode=i';

=item B<reject_file_mode> = I<permissions (octal)>

Permissions for rejected package files.

Default value: 0640

=cut

$Options{'reject_file_mode'} = 0640;
$OptionDefs{'reject_file_mode'} = 'reject_file_mode=i';

=item B<lock_file> => I<lockfile>

Location of the lockfile to use when running.

Default value: "$Options{'archive_dir'}/.lock"

=cut

$Options{'lock_file'} = "$Options{'archive_dir'}/.lock";
$OptionDefs{'lock_file'} = 'lock_file=s';

=item B<get_lock_path> => I<boolean>

Display the full path set for the lock file and exit. This is mainly used
to determine the path set for the lock file from a system's or user's
default configuration.

Default value: 0 (false)

=cut

$Options{'get_lock_path'} = 0;
$OptionDefs{'get_lock_path'} = 'get_lock_path!';

=back

=cut

=head2 Compression configuration

These values control what formats will be used to compress the
distribution files (Packages, Sources).

=over 4

=item B<compress_dists> = I<boolean>

This determines whether or not compressed versions of the distribution
files (Packages.gz, Sources.gz) are generated in gzip.

Default value: 0 (false)

=cut

$Options{'compress_dists'} = 0;
$OptionDefs{'compress_dists'} = 'compress_dists!';

=item B<bzcompress_dists> = I<boolean>

This determines whether or not compressed versions of the distribution
files (Packages.gz, Sources.gz) are generated in bzip2.

Default value: 0 (false)

=cut

$Options{'bzcompress_dists'} = 0;
$OptionDefs{'bzcompress_dists'} = 'bzcompress_dists!';

=back

=cut

=head2 Archive configuration

These values control which distributions, components, and architectures the
archive will support.

=over 4

=item B<dists> => I<hash of distribution names and codenames>

A hashref pointing to a hash with entries for all distributions we will
accept packages for, and what the current codename for each distribution
is. Note that it is acceptable for more than one distribution to point to a
given codename (for example, when frozen is active); however, this has some
strange (and non-deterministic) consequences for Release files.

Default value:

{ 'stable' => 'etch',
'testing' => 'lenny',
'unstable' => 'sid',
'experimental' => 'experimental' }

=cut

$Options{'dists'} = {
    'stable' => 'etch',
    'testing' => 'lenny',
    'unstable' => 'sid',
    'experimental' => 'experimental'
    };
$OptionDefs{'dists'} = 'dists=s%';

=item B<virtual_dists> => I<hash of virtual distribution names and targets>

A hashref pointing to a hash with entries for all 'virtual' distributions
we will accept packages for, and what distribution it should be treated
as. It is acceptable for more than one virtual distribution to point to a
given target. Note that unlike 'dists' entries, symlinks pointing from the
virtual name to the real name will not be created, and no attempt is made
to use these names in reverse processes (such as Release files); however,
virtual distributions may target any name ("unstable") or codename ("sid")
which appears in the 'dists' hash.

Default value:

{}

Example value:

{ 'unstable-hostname' => 'unstable',
  'testing-hostname' => 'lenny', }

=cut

$Options{'virtual_dists'} = {};
$OptionDefs{'virtual_dists'} = 'virtual_dists=s%';

=item B<sections> => I<array of section names>

An arrayref pointing to an array which lists all sections we will accept
packages for.

Default value: [ 'main', 'contrib', 'non-free', 'debian-installer' ]

=cut

$Options{'sections'} = [ 'main', 'contrib', 'non-free', 'debian-installer' ];
$OptionDefs{'sections'} = 'sections=s@';

=item B<archs> => I<array of architecture names>

An arrayref pointing to an array which lists all architectures we will
accept packages for. Note that 'source' will always be present, and 'all'
will be silently ignored (uploads for Arch: all will still work, but the
listings appear in arch-specific Packages files).

Default value: [ 'i386' ]

=back

=cut

$Options{'archs'} = [ 'i386' ];
$OptionDefs{'archs'} = 'archs=s@';

=head2 Release configuration

If the variables 'release_origin', 'release_label', and
'release_description' are defined, Release files will be generated
for each distribution directory.

Please note that enabling Release files will introduce a dependancy on the
package 'libdigest-sha-perl'.

See also: sign_release

=over 4

=cut

=item B<release_origin> => I<origin tag>

A string to be used for the Origin tag in the Release file.

Default value: undef

=cut

$Options{'release_origin'} = undef;
$OptionDefs{'release_origin'} = 'release_origin=s';

=item B<release_label> => I<label tag>

A string to be used for the Label tag in the Release file.

Default value: undef

=cut

$Options{'release_label'} = undef;
$OptionDefs{'release_label'} = 'release_label=s';

=item B<release_description> => I<description tag>

A string to be used for the Description tag in the Release file. (Note that
this should be a single line.)

Default value: undef

=cut

$Options{'release_description'} = undef;
$OptionDefs{'release_description'} = 'release_description=s';

=item B<release_noauto> = <array of NonAutomatic release names>

An array of release names which should be tagged with 'NonAutomatic: yes'
in their Release files. This tag will keep APT from ever automatically
selecting a package from that archive as an installation candidate.

Default value: [ 'experimental' ]

=cut

$Options{'release_noauto'} = [ 'experimental' ];
$OptionDefs{'release_noauto'} = 'release_noauto=s@';

=back

=cut

=head2 Signature configuration

Please note that enabling any of these options will cause a dependancy on
the 'gnupg' package. See F</usr/share/doc/debpool/README.GnuPG> for more
information.

=over 4

=item B<require_sigs_debs> = I<boolean>

If true, packages will be rejected unless their package files (.deb)
are GPG-signed with a recognized key found one of the keyrings listed
in 'gpg_keyrings'. These can be signed with the tools in the 'debsigs'
package.

Note that this option currently does nothing. It may be
implemented in a future version of debpool. However, it's also possible
that this option will be removed entirely as there seems to be
little support for signed .deb files in Debian.

Default value: 0 (false)

See also: gpg_keyrings

=cut

$Options{'require_sigs_debs'} = 0;
$OptionDefs{'require_sigs_debs'} = 'require_sigs_debs!';

=item B<require_sigs_meta> = I<boolean>

If true, packages will be rejected unless their meta-files (.changes and
.dsc) are GPG-signed with a recognized key found one of the keyrings listed
in 'gpg_keyrings'. These are the files normally signed by the 'debsign'
utility in devscripts package.

Default value: 0 (false)

See also: gpg_keyrings

=cut

$Options{'require_sigs_meta'} = 0;
$OptionDefs{'require_sigs_meta'} = 'require_sigs_meta!';

=item B<sign_release> = I<boolean>

If true, generated Release files will be GPG-signed with the key specified
in 'gpg_sign_key'.

Note that this will have no effect unless 'gpg_sign_key' is also defined at
some point.

Default value: 0 (false)

See also: L<"Release configuration">, gpg_sign_key

=cut

$Options{'sign_release'} = 0;
$OptionDefs{'sign_release'} = 'sign_release!';

=back

=cut

=head2 GnuPG configuration

These values will only be used if the use of GnuPG is triggered in some
fashion (such as any of the values in L<"Signature configuration"> being
enabled) , and thus do not (in themselves) trigger a dependancy on GnuPG.
Please see F</usr/share/doc/debpool/README.GnuPG> for more information.

=over 4

=item B<gpg_bin> = I<GnuPG binary>

This is used to specify the GnuPG binary to run.

Default value: '/usr/bin/gpg'

=cut

$Options{'gpg_bin'} = '/usr/bin/gpg';
$OptionDefs{'gpg_bin'} = 'gpg_bin=s';

=item B<gpg_home> = I<GnuPG homedir>

This is used to specify the GnuPG homedir (via the --homedir option).

Default value: $ENV{'HOME'}.'/.gnupg'

=cut

$Options{'gpg_home'} = $ENV{'HOME'}.'/.gnupg';
$OptionDefs{'gpg_home'} = 'gpg_home=s';

=item B<gpg_keyrings> = I<array of keyring filenames>

An arrayref pointing to an array which lists all of the GPG keyrings that
hold keys for approved uploaders. Note that this will have no effect unless
at least one of 'require_sigs_debs' or 'require_sigs_meta' is enabled.

Default value: [ 'uploaders.gpg' ]

See also: require_sigs_debs, require_sigs_meta

=cut

$Options{'gpg_keyrings'} = [ 'uploaders.gpg' ];
$OptionDefs{'gpg_keyrings'} = 'gpg_keyrings=s@';

=item B<gpg_sign_key> = I<signature keyID>

A string which contains the ID of the key which we will sign Release files
with. Note that this will have no effect unless 'sign_release' is true.

Default value: undef

See also: sign_release

=cut

$Options{'gpg_sign_key'} = undef;
$OptionDefs{'gpg_sign_key'} = 'gpg_sign_key=s';

=item B<gpg_passfile> = I<passphrase file>

This specifies the name of the file from which we read the GnuPG passphrase
for the key listed in gpg_sign_key. Note that it will have no effect unless
'sign_release' is true and 'gpg_sign_key' is defined.

Default value: $ENV{'HOME'}.'/.gnupg/passphrase';

See also: sign_release, gpg_sign_key

=cut

$Options{'gpg_passfile'} = $ENV{'HOME'}.'/.gnupg/passphrase';
$OptionDefs{'gpg_passfile'} = 'gpg_passfile=s';

=back

=head2 Logging configuration

These are values which control the logging system.

=over 4

=item B<log_file> = I<filename>

If this option is defined, logging output will be sent to the filename
specified. Note that an undefined value is considered an explicit request
to log nothing.

Default value: $ENV{'HOME'}.'/.debpool/debpool.log';

=cut

$Options{'log_file'} = $ENV{'HOME'}.'/.debpool/debpool.log';
$OptionDefs{'log_file'} = 'log_file=s';

=head2 Misc. configuration

These are values which don't particularly fit into any of the other
sections.

=over 4

=item B<daemon> = I<boolean>

This determines whether debpool runs as a daemon (never exiting except on
fatal errors, rescanning the Incoming directory periodically), or on a
single-run basis. True values cause debpool to run as a daemon.

Default value: 0 (false)

=cut

$Options{'daemon'} = 0;
$OptionDefs{'daemon'} = 'daemon!';

=item B<sleep> = I<delay>

This option determines how long the daemon sleeps for, between each
processing run. Note that signals (such as SIGHUP, SIGINT, or SIGTERM)
will force the daemon to wake up before this expires, so don't worry about
setting it too long.

Default value: 300 (5 minutes)

=cut

$Options{'sleep'} = 300;
$OptionDefs{'sleep'} = 'sleep=i';

=item B<use_inotify> = I<boolean>

Sets whether debpool should use inotify to monitor for incoming changes.

Default value: 0 (false)

=cut

$Options{'use_inotify'} = 0;
$OptionDefs{'use_inotify'} = 'use_inotify!';

=item B<rollback> = I<boolean>

This determines whether older packages in the incoming queue are allowed
to replace newer versions already in the archive (roll back the archive
version).

Default value: 0 (false)

=cut

$Options{'rollback'} = 0;
$OptionDefs{'rollback'} = 'rollback!';

=item B<rebuild-files> = I<boolean>

This option can be set in configfiles, but is more commonly used from the
commandline; if set, it forces all of the distribution files (Packages and
Sources) to be rebuilt, whether or not they need it. This should almost
never be used in conjunction with the daemon option.

Default value: 0 (false)

=cut

$Options{'rebuild-files'} = 0;
$OptionDefs{'rebuild-files'} = 'rebuild-files!';

=item B<rebuild-dbs> = I<boolean>

This option should not be set in configfiles, only used from the
commandline; if set, it forces all of the metadata files to be rebuilt from
scratch. This should almost never be used in conjunction with the daemon
option.

WARNING: This feature is not yet implemented, and will (silently) fail to
do anything, at this time. It will be implemented in a future version.

Default value: 0 (false)

=cut

$Options{'rebuild-dbs'} = 0;
$OptionDefs{'rebuild-dbs'} = 'rebuild-dbs!';

=item B<rebuild-all> = I<boolean>

This option should not be set in configfiles, only used from the
commandline; if set, it is equivalent to turning on all other rebuild
options (currently --rebuild-files and --rebuild-dbs).

WARNING: This feature depends on rebuild-dbs, which is not yet implemented;
only the --rebuild-files section will be triggered.

Default value: 0 (false)

=cut

$Options{'rebuild-all'} = 0;
$OptionDefs{'rebuild-all'} = 'rebuild-all!';

=item B<config> = I<configfile>

This is a special option that should not be put into configfiles; it is
intended only for command-line use. It may be issued multiple times; each
time it is used, it will add the named config file to the list which
DebPool will load (later config files override earlier ones, in case of any
conflicts).

Default value: N/A

=back

=cut
}

END {}

1;

__END__

=head1 CAVEATS

Command line options will override all Config.pm declarations.

=cut

=head1 SEE ALSO

L<debpool(1)>

=cut

=head1 AUTHOR

DebPool Developers <debpool-devel@lists.alioth.debian.org>

This manpage is autogenerated from F<share/DebPool/Config.pm> of the
source package during build time using pod2man.

=cut

# vim:set tabstop=4 expandtab:
