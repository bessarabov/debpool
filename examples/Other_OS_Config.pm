# Example DebPool configuration file for another OS distribution

# debpool can use the --config option to specify other configuration files
# to use besides the default system and user configurations. This can be
# useful when creating a pool layout that's used by another OS distribution.
# This configuration file is a configuration that can be used to setup
# debpool for use with Ubuntu. To use this, call debpool with the
# --config option and specify the location of a configuration file.
# For example: debpool --config ~/.debpool/Ubuntu_Config.pm

package DebPool::Config;

# A DebPool::Config file is a well-formed Perl module; it declares a
# package namespace of 'DebPool::Config', contains a definition of exactly
# one hash named 'Options', and declares a true value at the end of the
# file.

# File/Directory configuration
#
# These config values determine what directories various parts of the
# archive are put in, and what permissions those directories have, as well
# as the default permissions for files.
#
# NOTE: While debpool will attempt to create db_dir, dists_dir,
# incoming_dir, installed_dir, pool_dir, and reject_dir if they do not
# exist, it will *not* attempt to do this for archive_dir.
#
# WARNING: If you redefine archive_dir and you want the other four
# entries to reflect this by incorporating the new value, you *MUST*
# redefine them here (even if you simply use the default value of
# 'archive_dir'/<dirname>) so that they use the new definition of
# archive_dir.

$Options{'archive_dir'} = '/usr/local/src/ubuntu';
$Options{'db_dir'} = "$Options{'archive_dir'}/db";
#$Options{'db_dir_mode'} = 0750;
#$Options{'db_file_mode'} = 0640;
$Options{'dists_dir'} = "$Options{'archive_dir'}/dists";
#$Options{'dists_dir_mode'} = 0755;
#$Options{'dists_file_mode'} = 0644;
$Options{'incoming_dir'} = "$Options{'archive_dir'}/incoming";
#$Options{'incoming_dir_mode'} = 01775;
$Options{'installed_dir'} = "$Options{'archive_dir'}/installed";
#$Options{'installed_dir_mode'} = 0755;
#$Options{'installed_file_mode'} = 0644;
$Options{'pool_dir'} = "$Options{'archive_dir'}/pool";
#$Options{'pool_dir_mode'} = 0755;
#$Options{'pool_file_mode'} = 0644;
$Options{'reject_dir'} = "$Options{'archive_dir'}/reject";
#$Options{'reject_dir_mode'} = 0750;
#$Options{'reject_file_mode'} = 0640;
$Options{'lock_file'} = "$Options{'archive_dir'}/.lock";
#$Options{'compress_dists'} = 0;

# Archive configuration
#
# These values control which distributions, components, and architectures
# the archive will support.

$Options{'dists'} = {
    'dapper' => 'dapper',
    'gutsy' => 'gutsy',
    'hardy' => 'hardy'
};

#$Options{'virtual_dists'} = {
#};

$Options{'sections'} = [ 'main', 'restricted', 'universe', 'multiverse' ];
#$Options{'archs'} = [ 'i386' ];

# Release configuration

# If all of the variables below are defined (release_origin, release_label,
# and release_description), Release files will be generated for each
# distribution directory.
#
# Please note that enabling Release files will introduce a dependancy on
# the packages 'libdigest-md5-perl' and 'libdigest-sha1-perl'.

#$Options{'release_origin'} = undef;
#$Options{'release_label'} = undef;
#$Options{'release_description'} = undef;

#$Options{'release_noauto'} = [
#    'experimental',
#];

# Signature configuration

# Please note that enabling either of these options will cause a dependancy
# on the 'gnupg' package. See /usr/share/doc/debpool/README.GnuPG for more
# information.

#$Options{'require_sigs_debs'} = 0;
#$Options{'require_sigs_meta'} = 0;
#$Options{'sign_release'} = 0;

# GnuPG configuration

# These values will only be used if the use of GnuPG is triggered in some
# fashion (such as 'require_sigs' or 'sign_release' being true), and
# thus do not (in themselves) trigger a dependancy on GnuPG. Please see
# /usr/share/doc/debpool/README.GnuPG for more information.

#$Options{'gpg_bin'} = '/usr/bin/gpg';
#$Options{'gpg_home'} = '/home/user/.gnupg';
#$Options{'gpg_keyrings'} = [ 'uploaders.gpg' ];
#$Options{'gpg_sign_key'} = undef;
#$Options{'gpg_passfile'} = '/home/user/.gnupg/passphrase';

# Logging configuration
#
# These are values which control the logging system.

#$Options{'log_file'} = '/home/user/.debpool/DebPool.log';

# Misc. configuration

# These are values which don't particularly fit into any of the other
# sections.

#$Options{'daemon'} = 0;
#$Options{'sleep'} = 300;
#$Options{'rollback'} = 0;
#$Options{'rebuild-files'} = 0;
#$Options{'rebuild-dbs'} = 0;
#$Options{'rebuild-all'} = 0;

# We're a module, so return a true value.

1;
