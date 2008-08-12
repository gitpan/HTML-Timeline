#!/usr/bin/perl
#
# Name:
#	timeline.pl.
#
# Description:
#	Convert a Gedcom file into a Timeline file.
#
# Output:
#	o Exit value
#
# History Info:
#	Rev		Author		Date		Comment
#	1.00   	Ron Savage	20080811	Initial version <ron@savage.net.au>

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use HTML::Timeline;

# --------------------

my($option_parser) = Getopt::Long::Parser -> new();

my(%option, @option);

push @option, 'ancestors';
push @option, 'everyone';
push @option, 'gedcom_file=s';
push @option, 'help';
push @option, 'include_spouses';
push @option, 'root_person=s';
push @option, 'verbose';
push @option, 'xml_file=s';

if ($option_parser -> getoptions(\%option, @option) )
{
	pod2usage(1) if ($option{'help'});

	exit HTML::Timeline -> new(options => \%option) -> run();
}
else
{
	pod2usage(2);
}

__END__

=pod

=head1 NAME

timeline.pl - Convert a Gedcom file into a Timeline file

=head1 SYNOPSIS

timeline.pl [options]

	Options:
	-ancestors
	-everyone
	-getcom_file a_file_name
	-help
	-include_spouses
	-root_person a_personal_name
	-verbose
	-xml_file a_file_name

Exit value:

=over 4

=item Zero

Success.

=item Non-Zero

Error.

=back

=head1 OPTIONS

=over 4

=item -ancestors

If this option is used, the ancestors of the root_person (see below) are processed.

If this option is not used, their descendents are processed.

=item -everyone

If this option is used, everyone is processed, and the root_person (see below) is ignored.

If this option is not used, the root_person is processed.

=item -gedcom_file a_file_name

The name of your Gedcom input file.

The default value is bach.ged (so timeline.pl runs OOTB [out-of-the-box]).

=item -help

Print help and exit.

=item -include_spouses

If this option is used, and descendents are processed, spouses are included.

If this option is not used, spouses are ignored.

=item -root_person a_personal_name

The name of the person on which to base the timeline.

The default is 'Johann Sebastian Bach'.

=item -verbose

Print verbose messages.

The default value for verbose is 0.

=item -xml_file a_file_name

The name of your XML output file.

The default value is 'timeline.xml'.

Note: The name of the XML file is embedded in timeline.html, at line 28.
You will need to edit this file if you do not use 'timeline.xml' as your XML output file.

=back

=head1 DESCRIPTION

timeline.pl converts a Gedcom file into a Timeline file.

See http://simile.mit.edu/timeline for details.

=cut