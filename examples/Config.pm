# DebPool configuration file

package DebPool::Config;

# A DebPool::Config file is a well-formed Perl module; it declares a
# package namespace of 'DebPool::Config', contains a definition of exactly
# one hash named 'Options', and declares a true value at the end of the
# file. See the DebPool::Config(5) man page for more information on the
# available options.

# File/Directory configuration
#
# These config values determine what directories various parts of the archive
# are put in, and what permissions those directories have, as well as the
# default permissions for files.
#
# NOTE: While debpool will attempt to create db_dir, dists_dir, incoming_dir,
# installed_dir, pool_dir, and reject_dir if they do not exist, it will *not*
# attempt to do this for archive_dir.
#
# WARNING: If you redefine archive_dir and you want the other four entries to
# reflect this by incorporating the new value, you *MUST* redefine them here
# (even if you simply use the default value of 'archive_dir'/<dirname>) so
# that they use the new definition of archive_dir.

#$Options{'archive_dir'} = '/var/cache/debpool';
#$Options{'db_dir'} = "$Options{'archive_dir'}/db";
#$Options{'db_dir_mode'} = 0750;
#$Options{'db_file_mode'} = 0640;
#$Options{'dists_dir'} = "$Options{'archive_dir'}/dists";
#$Options{'dists_dir_mode'} = 0755;
#$Options{'dists_file_mode'} = 0644;
#$Options{'incoming_dir'} = "$Options{'archive_dir'}/incoming";
#$Options{'incoming_dir_mode'} = 01775;
#$Options{'installed_dir'} = "$Options{'archive_dir'}/installed";
#$Options{'installed_dir_mode'} = 0755;
#$Options{'installed_file_mode'} = 0644;
#$Options{'pool_dir'} = "$Options{'archive_dir'}/pool";
#$Options{'pool_dir_mode'} = 0755;
#$Options{'pool_file_mode'} = 0644;
#$Options{'reject_dir'} = "$Options{'archive_dir'}/reject";
#$Options{'reject_dir_mode'} = 0750;
#$Options{'reject_file_mode'} = 0640;
#$Options{'lock_file'} = "$Options{'archive_dir'}/.lock";

# Compression configuration

# These values control what formats will be used to compress the distribution
# files (Packages, Sources).

#$Options{'compress_dists'} = 0;
#$Options{'bzcompress_dists'} = 0;

# Archive configuration
#
# These values control which distributions, components, and architectures the
# archive will support.

#$Options{'dists'} = {
#    'stable' => 'etch',
#    'testing' => 'lenny',
#    'unstable' => 'sid',
#    'experimental' => 'experimental'
#    };
#$Options{'virtual_dists'} = {};
#$Options{'sections'} = [ 'main', 'contrib', 'non-free', 'debian-installer' ];
#$Options{'archs'} = [ 'i386' ];

# Release configuration

# If the variables 'release_origin', 'release_label', and 'release_description'
# are defined, Release files will be generated for each distribution directory.

# Please note that enabling Release files will introduce a dependancy on the
# package 'libdigest-sha-perl'.

#$Options{'release_origin'} = undef;
#$Options{'release_label'} = undef;
#$Options{'release_description'} = undef;
#$Options{'release_noauto'} = [ 'experimental' ];

# Signature configuration

# Please note that enabling any of these options will cause a dependancy on
# the 'gnupg' package. See /usr/share/doc/debpool/README.GnuPG for more
# information.

#$Options{'require_sigs_debs'} = 0;
#$Options{'require_sigs_meta'} = 0;
#$Options{'sign_release'} = 0;

# GnuPG configuration

# These values will only be used if the use of GnuPG is triggered in some
# fashion (such as any of the values in ``Signature configuration'' being
# enabled) , and thus do not (in themselves) trigger a dependancy on GnuPG.
# Please see /usr/share/doc/debpool/README.GnuPG for more information.

#$Options{'gpg_bin'} = '/usr/bin/gpg';
#$Options{'gpg_home'} = $ENV{'HOME'}.'/.gnupg';
#$Options{'gpg_keyrings'} = [ 'uploaders.gpg' ];
#$Options{'gpg_sign_key'} = undef;
#$Options{'gpg_passfile'} = $ENV{'HOME'}.'/.gnupg/passphrase';

# Logging configuration

# These are values which control the logging system.

#$Options{'log_file'} = $ENV{'HOME'}.'/.debpool/debpool.log';

# Misc. configuration

# These are values which don't particularly fit into any of the other sections.

#$Options{'daemon'} = 0;
#$Options{'sleep'} = 300;
#$Options{'use_inotify'} = 0;
#$Options{'rollback'} = 0;
#$Options{'rebuild-files'} = 0;
#$Options{'rebuild-dbs'} = 0;
#$Options{'rebuild-all'} = 0;

# This file is a module, so return a true value.

1;
