package DebPool::Parser;

###
#
# DebPool::Parser - Module for parsing changes and dsc files
#
# Copyright 2008 Andres Mejia. All rights reserved.
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
# $Id: Parser.pm 27 2008-10-23 03:06:59Z andres $
#
###

# We use 'our', so we must have at least Perl 5.6

require 5.006_000;

# Always good ideas.

use strict;
use warnings;

use POSIX; # WEXITSTATUS

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
        &Parse_File
    );

    %EXPORT_TAGS = (
        'functions' => [qw(&Parse_File)],
        'vars' => [qw()],
    );
}

### Exported package globals

### Non-exported package globals

# Thread-safe? What's that? Package global error value. We don't export
# this directly, because it would conflict with other modules.

our($Error);

# Hash of potential fields and what they should be represented as
my %Field_Types = (
    # All fields that can be found either in changes or dsc files
    'Format' => 'string', # both
    'Date' => 'string', # changes
    'Source' => 'string', # both
    'Binary' => 'space_array', # both (comma_array in dsc file)
    'Architecture' => 'space_array', # both
    'Version' => 'string', # both
    'Distribution' => 'space_array', # both
    'Urgency' => 'string', # changes
    'Maintainer' => 'string', # both
    'Changed-By' => 'string', # changes
    'Description' => 'multiline_array', # changes
    'Closes' => 'space_array', # changes
    'Changes' => 'multiline_array', # changes
    'Checksums-Sha1' => 'checksums', # both
    'Checksums-Sha256' => 'checksums', # both
#    'Files' => 'checksums', # both (of 'file_entries' type for changes file)
    'Uploaders' => 'comma_array', # dsc
    'Homepage' => 'string', # dsc
    'Standards-Version' => 'string', # dsc
#    'Vcs-Any' => 'string', # The Vcs-* entries will all be strings
    'Build-Depends' => 'comma_array', # dsc
    'Build-Depends-Indep' => 'comma_array', # dsc
    'Dm-Upload-Allowed' => 'string', #dsc
#    'X-Any-Fields' => 'multiline_array', # both
    'Source-Version' => 'string', # used when binNMU is detected

    # The rest of these fields are found in the control file of a package.
    'Package' => 'string',
    'Priority' => 'string',
    'Section' => 'string',
    'Installed-Size' => 'string',
    'Essential' => 'string',
    'Pre-Depends' => 'comma_array',
    'Depends' => 'comma_array',
    'Provides' => 'comma_array',
    'Conflicts' => 'comma_array',
    'Recommends' => 'comma_array',
    'Suggests' => 'comma_array',
    'Enhances' => 'comma_array',
    'Replaces' => 'comma_array',
);

### File lexicals

# None

### Constant functions

# None

### Meaningful functions

# Parse_File($file)
#
# Parses a changes or dsc file. This method returns a hash reference of the
# different types of data we want from each field. We use an internal method to
# help us in placing an appropriate data type for each field (key) of our hash.

sub Parse_File {
    my ($file) = @_;

    use DebPool::GnuPG qw(:functions); # To strip GPG encoding
    use DebPool::Logging qw(:functions :facility :level);

    # Read in the entire file, stripping GPG encoding if we find
    # it. It should be small, this is fine.
    my $fh;
    if (!open($fh, '<', $file)) {
        Log_Message("Couldn't open file '$file': $!", LOG_GENERAL, LOG_ERROR);
        return;
    }
    my @data = <$fh>;
    close $fh;
    chomp @data;
    @data = Strip_GPG(@data);

    # Add a key in a hash corresponding to the Field of the file we're parsing.
    # Then add the corresponding values. We first start by adding the values
    # in an array.
    my ($field, @values, %fields);
    foreach my $line (@data) {
        if ($line eq '') {
            last; # End of the paragraph (stanza)
        } elsif ($line =~ m/^([^:\s]+):\s?(.*)$/) {
            # We process entries for the last field so we must ensure that we
            # have a field to process. This is the usual case during the first
            # loop.
            if ($field) {
                $fields{$field} = Process_Type($field, $file, \@values);
            }
            @values = ();
            $field = $1;
            if ($2) { # Only add entries if there's something to add
                push @values, $2;
            }
        } else { #Still in the same field
            push @values, $line;
        }
    }
    # Once we're done with the for loop, we still have to process the last
    # field.
    if ($field) {
        $fields{$field} = Process_Type($field, $file, \@values);
    }

    # In case a valid binNMU is detected, Source will be written as
    # <package> (<original_version>). We must strip the extra version from the
    # string.
    if (defined $fields{'Source'}) {
        ($fields{'Source'}, $fields{'Source-Version'}) =
            split(/ /, $fields{'Source'});
    }
    if (defined $fields{'Source-Version'}) {
        $fields{'Source-Version'} =~ s/^\(|\)$//g;
    }

    return \%fields;
}

# Process_Type($field, $file, $values)
# Parameter data types (string, string, array_ref)
#
# This method will return a string, an array, or a hash depending on the field
# we are processing.

sub Process_Type {
    my ($field, $file, $values) = @_;

    # Change the field type of certain fields to appropriate type dependending
    # on the file being parsed.
    if ($field eq 'Files') {
        if ($file =~ m/^.*\Q.changes\E$/) {
            $Field_Types{$field} = 'file_entries';
        } else {
            $Field_Types{$field} = 'checksums';
        }
    }
    if ($field eq 'Binary') {
        if ($file =~ m/^.*\Q.dsc\E$/) {
            $Field_Types{$field} = 'comma_array';
        } else {
            $Field_Types{$field} = 'space_array';
        }
    }

    # Add the Vcs-* entries into the %Field_Types hash. We do this to
    # compensate for the many different Vcs-* entries that may exist
    if ($field =~ m/^Vcs-.*$/) {
        $Field_Types{$field} = 'string';
    }

    # Make all unknown fields of type multiline_array for now.
    if (!grep {$_ eq $field} (keys %Field_Types)) {
        $Field_Types{$field} = 'multiline_array';
    }

    if ($Field_Types{$field} eq 'string') {
        return ${$values}[0];
    } elsif ($Field_Types{$field} eq 'space_array') {
        my @data = split /\s+/, ${$values}[0];
        return \@data;
    } elsif ($Field_Types{$field} eq 'comma_array') {
        my @data = split /,\s+/, ${$values}[0];
        return \@data;
    } elsif ($Field_Types{$field} eq 'multiline_array') {
        return $values;
    } elsif ($Field_Types{$field} eq 'checksums') {
        # Checksum types are a special case. We return a hash where the
        # filenames are the keys, each containing the value of the checksum and
        # size inside an array, the first element being the checksum and the
        # second element being the size.
        my %data;
        foreach my $value (@{$values}) {
            my (undef, $checksum, $size, $file) = split /\s+/, $value;
            $data{$file} = [ $checksum, $size ];
        }
        return \%data;
    } elsif ($Field_Types{$field} eq 'file_entries') {
        # File entries in a changes file are similar to the checksum type,
        # except that they also include the section and priority of a file.
        # So the first element is the checksum, the second is the size, the
        # third is the section and the fourth is the priority.
        my %data;
        foreach my $value (@{$values}) {
            my (undef, $checksum, $size, $section, $priority, $file) =
                split /\s+/, $value;
            $data{$file} = [ $checksum, $size, $section, $priority ];
        }
        return \%data;
    } else { # Treat all unknown fields as multiline_arrays for now
        return $values;
    }
}

END {}

1;

__END__

# vim:set tabstop=4 expandtab:
