package POE::Component::Jabber::J14;
use warnings;
use strict;

use 5.010;
use POE;
use POE::Component::Jabber::Events;
use POE::Filter::XML;
use POE::Filter::XML::Node;
use POE::Filter::XML::NS qw/ :JABBER :IQ /;
use Digest::SHA1 qw/ sha1_hex /;

use base('POE::Component::Jabber::Protocol');

our $VERSION = '3.00';

sub get_version()
{
	return '0.9';
}

sub get_xmlns()
{
	return +NS_JABBER_ACCEPT;
}

sub get_states()
{
	return [ 'set_auth', 'init_input_handler' ];
}

sub get_input_event()
{
	return 'init_input_handler';
}

sub set_auth()
{
	my ($kernel, $heap, $self) = @_[KERNEL, HEAP, OBJECT];

	my $node = POE::Filter::XML::Node->new('handshake');
	my $config = $heap->config();
	$node->appendText(sha1_hex($self->{'sid'}.$config->{'password'}));
	$kernel->post($heap->events(), +PCJ_AUTHNEGOTIATE);
	$kernel->yield('output_handler', $node, 1);
	return;
}

sub init_input_handler()
{
	my ($kernel, $heap, $self, $node) = @_[KERNEL, HEAP, OBJECT, ARG0];
	
    given($node->nodeName())
    {
        when('handshake')
        {	
            my $config = $heap->config();
            $kernel->post($heap->events(), +PCJ_AUTHSUCCESS);
            $kernel->post($heap->events(), +PCJ_READY);
            $heap->jid($config->{'hostname'});
            $heap->relinquish_states();

        }
        
        when('stream:stream')
        {
            $self->{'sid'} = $node->getAttribute('id');
            $kernel->yield('set_auth');
        
        }

        default
        {
            $heap->debug_message('Unknown state: ' . $node->toString());
            $kernel->post($heap->events(), +PCJ_AUTHFAIL);
        }
    }
}

1;

__END__

=pod

=head1 NAME

POE::Component::Jabber::J14

=head1 SYNOPSIS

PCJ::J14 is a Protocol implementation that connects as a service to a jabberd14
server.

=head1 DESCRIPTION

PCJ::J14 authenticates with the server backend using the method outlined in 
XEP-114 (Jabber Component Protocol) 
[http://www.xmpp.org/extensions/xep-0114.html]

=head1 METHODS

Please see PCJ::Protocol for what methods this class supports.

=head1 EVENTS

Listed below are the exported events that end up in PCJ's main session:

=over 2

=item set_auth

This event constructs and sends the <handshake/> element for authentication.

=item init_input_handler

This is out main entry point that PCJ uses to send us all of the input. It
handles the authentication response.

=back

=head1 NOTES AND BUGS

This only implements the jabber:component:accept namespace (ie. the component
initiates the connection to the server).

Also be aware that before this protocol was documented as an XEP, it was widely
implemented with loose rules. I conform to this document. If there is a problem
with the implementation against older server implementations, let me know.

The underlying backend has changed this release to now use a new Node
implementation based on XML::LibXML::Element. Please see POE::Filter::XML::Node
documentation for the relevant API changes.

=head1 AUTHOR

Copyright (c) 2003-2009 Nicholas Perez. Distributed under the GPL.

=cut
