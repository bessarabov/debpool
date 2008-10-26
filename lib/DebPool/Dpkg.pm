package DebPool::Dpkg;

###
#
# DebPool::Dpkg - Module that performs dpkg operations using pure Perl
#
# Copyright 2008 Andres Mejia. All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id: Dpkg.pm 27 2008-10-25 03:06:59Z andres $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

use File::Temp qw(tempfile); # For making tempfiles
use Archive::Ar; # For extracting ar files (the format for .deb files)
use Archive::Tar; # For extracting tar files

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
        &Dpkg_Field
        &Compare_Version
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Dpkg_Field &Compare_Version)],
        'vars' => [qw()],
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

### Constant functions

# None

### Meaningful functions

# Dpkg_Field($file, $fields)
# Parameter data types (string, array_ref)
#
# Method that mimics the behavior of 'dpkg --field <deb_file> [fields]'. This is
# the pure perl method of performing said operation. We return the contents of
# the control file in an array reference.
#
# Note that this is actually a dpkg-deb operation.

sub Dpkg_Field {
    my ($file, $fields) = @_;

    # First get the contents of the control gzip tarball from the deb file.
    my $ar = Archive::Ar->new($file);
    # get_content() returns a hash reference
    my $ar_control = $ar->get_content("control.tar.gz");

    # Now write the control gzip tarball into a tempfile.
    my ($control_tar_gz_fh, $control_tar_gz) = tempfile();
    print $control_tar_gz_fh $ar_control->{data};
    binmode $control_tar_gz_fh;

    # Now extract and read the contents of the control file to an array.
    my ($control_fh, $control_file) = tempfile();
    my $control_tar_object = Archive::Tar->new($control_tar_gz,1);
    $control_tar_object->extract_file('./control',$control_file);
    my @control_file_data = <$control_fh>;

    # Just return our control file data if we didn't specify any fields
    return \@control_file_data if (!$fields);

    # If we did specify fields, include only those fields in the output. Also,
    # if we specified only one field, strip the field name from the output.
    my @output;
    my $pattern = "(" . join('|', @{$fields}) . ")";
    my $newfield = 0; # use as boolean
    foreach my $tmp (@control_file_data) {
        if (!$pattern) {
            push @output, $tmp;
        } elsif ($tmp =~ /^$pattern:/) {
            $newfield = 1;
            push @output, $tmp;
        } elsif ($newfield and $tmp =~ /^ /) {
            push @output, $tmp;
        } else {
            $newfield = 0;
        }
    }
    $output[0] =~ s/^$pattern: (.*)/$2/ if (@{$fields} eq 1);
    return \@output;
}

# Compare_Version($version1, $operator, $version2)
# Paramater data types (string, string, string)
#
# Method that compares two version numbers and returns either 1 or 0 (true or
# false) based on whether '$version1 $operator $version2' is a true statement.
#
# TODO: For now, we just use dpkg. We'll make this a pure Perl subroutine later.

sub Compare_Version {
    my ($version1, $operator, $version2) = @_;

    my $dpkg_bin = '/usr/bin/dpkg';
    my @args = ('--compare-versions', $version1, $operator, $version2);
    if (system($dpkg_bin, @args) eq 0) {
        return 1;
    } else {
        return 0;
    }
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
