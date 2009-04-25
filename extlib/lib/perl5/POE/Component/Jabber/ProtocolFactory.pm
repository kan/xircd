package POE::Component::Jabber::ProtocolFactory;
use warnings;
use strict;

use Carp;
use POE::Component::Jabber::XMPP;
use POE::Component::Jabber::Legacy;
use POE::Component::Jabber::J14;
use POE::Component::Jabber::J2;

use constant
{
	'JABBERD14_COMPONENT'	=> 0,
	'LEGACY'				=> 1,
	'JABBERD20_COMPONENT'	=> 2,
	'XMPP'					=> 4,
};

use base('Exporter');
our @EXPORT = qw/ JABBERD14_COMPONENT JABBERD20_COMPONENT LEGACY XMPP /;

our $VERSION = '3.00';

sub get_guts($)
{
	my $type = shift(@_);
	
	Carp::confess('No argument provided') if not defined($type);
	Carp::confess('Invalid Helper type: ' . $type) if $type =~ /\D+/;

	if($type == +XMPP)
	{
		return POE::Component::Jabber::XMPP->new();
	
	} elsif ($type == +LEGACY) {

		return POE::Component::Jabber::Legacy->new();
	
	} elsif ($type == +JABBERD14_COMPONENT) {

		return POE::Component::Jabber::J14->new();

	} elsif ($type == +JABBERD20_COMPONENT) {

		return POE::Component::Jabber::J2->new();
	
	} else {

		Carp::confess('Unknown Helper type: ' . $type);
	}
}

1;

__END__

=pod

=head1 NAME

POE::Component::Jabber::ProtocolFactory

=head1 SYNOPSIS

PCJ::ProtocolFactory is a protected helper class used to instantiate specific 
Protocols based on exported constants

=head1 DESCRIPTION

PCJ internally uses PCJ::ProtocolFactory to turn the ConnectionType argument 
into a Protocol object used to implement the various supported dialects. This
is why the accepted arguments are exported as constants upon use.

=head1 FUNCTIONS

By default no functions are exported beyond the accepted arguments. Only a 
package function is available:

=over 4 

=item get_guts [Protected]

get_guts takes a single argument and that is a defined constant exported by 
this module. It returns a PCJ::Protocol object.

See PCJ::Protocol for details on its methods and implementing different 
Protocols.

=back

=head1 CONSTANTS

Below are the constants that are exported. Their names are rather 
self-explanatory:

=over 4

=item XMPP


=item LEGACY


=item JABBERD14_COMPONENT


=item JABBERD20_COMPONENT

=back

=head1 NOTES

All supported Protocol types are implemented herein. get_guts will confess if it
receives an invalid argument.

=head1 AUTHOR

(c) Copyright 2007-2009 Nicholas Perez. Released under the GPL.

=cut
