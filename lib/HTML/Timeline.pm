package HTML::Timeline;

# Author:
#	Ron Savage <ron@savage.net.au>
#
# Note:
#	\t = 4 spaces || die.

use strict;
use warnings;

require 5.005_62;

require Exporter;

use accessors::classic qw/ancestors everyone format gedcom_file gedobj include_spouses root_person verbose xml_file/;
use Carp;
use Date::Manip ();
use Gedcom;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use HTML::Timeline ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '1.00';

# -----------------------------------------------

sub clean_persons_name
{
	my($self, $name) = @_;

	# Find /s everwhere (/g) and remove them.

	$name =~ s|/||g;

	return $name;

} # End of clean_persons_name.

# -----------------------------------------------

sub generate_xml_file
{
	my($self, $people) = @_;

	my($birth_date);
	my($death_date);
	my($extracted_date);
	my(@missing);
	my($name, %notes);
	my($person);
	my($result);
	my(%seen);
	my(@xml);

	push @xml, '<data>';

	for $person (@$people)
	{
		$name = $person -> get_value('name');

		if ($seen{$name})
		{
			$self -> log(sprintf($self -> format(), 'Note', "$name appears twice in the input file") );

			next;
		}

		$seen{$name} = 1;
		$name        = $self -> clean_persons_name($name);
		$birth_date  = $person -> get_value('birth date');
		$death_date  = $person -> get_value('death date');

		# Process birth dates.

		if (Date::Manip::ParseDate($birth_date) )
		{
			$notes{$name} = '';
		}
		elsif ($birth_date)
		{
			$notes{$name}    = "Fuzzy birthdate: $birth_date";
			($extracted_date = $birth_date) =~ /(\d{4})/;

			if ($extracted_date)
			{
				$birth_date = $extracted_date;
			}
		}
		else
		{
			push @missing, $name;

			next;
		}

		# Process death dates.

		if (Date::Manip::ParseDate($death_date) )
		{
			# James Riley Durbin's death date (FEB 1978) is parseable by ParseDate
			# but not Similie Timeline, so we only extract the year.

			if ($name eq 'James Riley Durbin')
			{
				($extracted_date = $death_date) =~ /(\d{4})/;

				if ($extracted_date)
				{
					$death_date = $extracted_date;
				}
			}
		}
		elsif ($death_date)
		{
			($extracted_date = $death_date) =~ /(\d{4})/;

			if ($extracted_date)
			{
				$death_date = $extracted_date;
			}
		}

		if ($birth_date && $death_date)
		{
			push @xml, qq|  <event title="$name" start="$birth_date" end="$death_date">$notes{$name}</event>|;
		}
		elsif ($birth_date)
		{
			push @xml, qq|  <event title="$name" start="$birth_date">$notes{$name}</event>|;
		}
	}

	if (@missing)
	{
		my($today)   = Date::Manip::UnixDate(Date::Manip::ParseDate('today'), '%b %e %Y');
		my($message) = 'People excluded because of missing birth dates: ' . join(', ', @missing);

		push @xml, qq|  <event title="Missing" start="$today">$message</event>|;
	}

	push @xml, '</data>';

	open(OUT, '> ' . $self -> xml_file() ) || Carp::croak "Can't open(> " . $self -> xml_file() . "): $!";
	print OUT join("\n", @xml), "\n";
	close OUT;

	$self -> log(sprintf($self -> format(), 'Created', $self -> xml_file() ) );

} # End of generate_xml_file.

# -----------------------------------------------

sub get_spouses
{
	my($self, $people) = @_;
	my($spouses)       = [];

	my($person);
	my($spouse);

	for my $person (@$people)
	{
		if ($person -> spouse() )
		{
			$spouse = $person -> spouse();

			push @$spouses, $spouse;
		}
	}

	return $spouses;

} # End of get_spouses.

# -----------------------------------------------

sub log
{
	my($self, $message) = @_;

	if ($self -> verbose() )
	{
		print STDERR "$message\n";
	}

} # End of log.

# -----------------------------------------------

sub new
{
	my($class, %arg)    = @_;
	my($self)           = bless({}, $class);
	my(@options)        = (qw/ancestors everyone gedcom_file include_spouses root_person verbose xml_file/);

	# Set defaults.

	$self -> ancestors(0);
	$self -> everyone(0);
	$self -> format('%-15s: %s'); # Not in the @options array!
	$self -> gedcom_file('bach.ged');
	$self -> gedobj(''); # Not in the @options array!
	$self -> include_spouses(0);
	$self -> root_person('Johann Sebastian Bach');
	$self -> verbose(0);
	$self -> xml_file('timeline.xml');

	# Process user options.

	my($attr_name);

	for $attr_name (@options)
	{
		if (exists($arg{'options'}{$attr_name}) )
		{
			$self -> $attr_name($arg{'options'}{$attr_name});
		}
	}

	if (! -f $self -> gedcom_file() )
	{
		Carp::croak 'Cannot find file: ' . $self -> gedcom_file();
	}

	$self -> gedobj
	(
	 Gedcom -> new
	 (
	  callback        => undef,
	  gedcom_file     => $self -> gedcom_file(),
	  grammar_version => '5.5',
	  read_only       => 1,
	 )
	);

	if (! $self -> gedobj() -> validate() )
	{
		Carp::croak 'Cannot validate file: ' . $self -> gedcom_file();
	}

	$self -> log('Parameters:');

	for $attr_name (@options)
	{
		$self -> log(sprintf($self -> format(), $attr_name, $self -> $attr_name() ) );
	}

	$self -> log('-' x 50);

	return $self;

}	# End of new.

# -----------------------------------------------

sub run
{
	my($self) = @_;

	$self -> log('Processing:');

	my($root_person) = $self -> gedobj() -> get_individual($self -> root_person() );
	my($name)        = $self -> clean_persons_name($root_person -> name() );

	my(@people);

	if ($self -> everyone() == 1)
	{
		@people = $self -> gedobj() -> individuals();
	}
	else
	{
		my($method) = $self -> ancestors() == 1 ? 'ancestors' : 'descendents';
		@people     = $root_person -> $method();

		$self -> log(sprintf($self -> format(), 'Relationship', $method) );

		if ($self -> ancestors() == 0)
		{
			# If descendents are wanted, check for spouses.

			if ($self -> include_spouses() == 1)
			{
				push @people, @{$self -> get_spouses(\@people)};
			}
		}
		else
		{
			# If ancestors are wanted, check for siblings.

			push @people, $root_person -> siblings();
		}

		unshift @people, $root_person;
	}

	$self -> generate_xml_file(\@people);
	$self -> log('Success');

	return 0;

} # End of run.

# -----------------------------------------------

1;

=head1 NAME

C<HTML::Timeline> - Convert a Gedcom file into a Timeline file

=head1 Synopsis

	shell> bin/timeline.pl -h

=head1 Description

C<HTML::Timeline> is a pure Perl module.

=head1 Distributions

This module is available as a Unix-style distro (*.tgz).

See http://savage.net.au/Perl-modules.html for details.

See http://savage.net.au/Perl-modules/html/installing-a-module.html for
help on unpacking and installing.

=head1 Constructor and initialization

new(...) returns an object of type C<HTML::Timeline>.

This is the class's contructor.

Usage: C<< HTML::Timeline -> new() >>.

This method takes a hashref of options.

Call C<new()> as C<< new({option_1 => value_1, option_2 => value_2, ...}) >>.

Available options:

=over 4

=item ancestors

If this option is 1, the ancestors of the root_person (see below) are processed.

If this option is 0, their descendents are processed.

The default is 0.

=item everyone

If this option is 1, everyone is processed, and the root_person (see below) is ignored.

If this option is 0, the root_person is processed.

The default is 0.

=item gedcom_file

This takes the name of your input Gedcom file.

The default is bach.ged.

=item include_spouses

If this option is 1, and descendents are processed, spouses are included.

If this option is 0, spouses are ignored.

The default is 0.

=item root_person

The name of the person on which to base the timeline.

The default is 'Johann Sebastian Bach'.

=item verbose

This takes either a 0 or a 1.

Write more or less progress messages to STDERR.

The default value is 0.

=item xml_file

The name of your XML output file.

The default value is 'timeline.xml'.

Note: The name of the XML file is embedded in timeline.html, at line 28.
You will need to edit the latter file if you use a different name for your XML output file.

=back

=head1 Method: log($message)

If C<new()> was called as C<< new({verbose => 1}) >>, write the message to STDERR.

If C<new()> was called as C<< new({verbose => 0}) >> (the default), do nothing.

=head1 Method: run()

Do everything.

See C<examples/timeline.pl> for an example of how to call C<run()>.

=head1 Required Modules

Some of these are only used by C<bin/timeline.pl>.

=over 4

=item accessors

=item Carp

=item Date::Manip

=item Gedcom

=item Getopt::Long

=item Pod::Usage

=back

=head1 See also

The C<Gedcom> module.

=head1 Support

Support is via the Gedcom mailing list.

Subscribe via perl-gedcom-subscribe@perl.org.

=head1 Credits

The MIT Simile Timeline project, and others, are at http://code.google.com/p/simile-widgets/.

Its original home is at http://simile.mit.edu/timeline.

Philip Durbin write the program examples/ged2xml.pl, which Ron Savage converted into a module.

Philip also supplied the files examples/bach.* and examples/timeline.html.

Ron Savage wrote bin/timeline.pl.

examples/timeline.xml is the output of this program, using the default options.

=head1 Author

C<HTML::Timeline> was written by Ron Savage in 2008. [ron@savage.net.au]

Home page: http://savage.net.au/index.html

=head1 Copyright

Australian copyright (c) 2008, Ron Savage.

	All Programs of mine are 'OSI Certified Open Source Software';
	you can redistribute them and/or modify them under the terms of
	The Artistic License, a copy of which is available at:
	http://www.opensource.org/licenses/index.html

=cut
