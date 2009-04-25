package POE::Component::Jabber::Legacy;
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
	return +NS_JABBER_CLIENT;
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
	my ($kernel, $heap) = @_[KERNEL, HEAP];
	
	my $config = $heap->config();
	my $node = POE::Filter::XML::Node->new('iq', ['type', +IQ_SET, 'id', 'AUTH']);
	my $query = $node->appendChild('query', ['xmlns', +NS_JABBER_AUTH]);

	$query->appendChild('username')->appendText($config->{'username'});

	if($config->{'plaintext'})
	{
		$query->appendChild('password')->appendText($config->{'password'});
	
	} else {

		my $hashed = sha1_hex($heap->sid().$config->{'password'});
		
		$query->appendChild('digest')->appendText($hashed);
	}
	
	$query->appendChild('resource')->appendText($config->{'resource'});

	$kernel->yield('output_handler', $node, 1);

	$heap->jid($config->{'username'} . '@' . $config->{'hostname'} . '/' .
		$config->{'resource'});
	
	return;
}

sub init_input_handler()
{
	my ($kernel, $heap, $node) = @_[KERNEL, HEAP, ARG0];
	
	my $config = $heap->config();

	if ($config->{'debug'})
	{
		$heap->debug_message( "Recd: ".$node->toString() );
	}
	
    given($node->nodeName())
    {
        when('stream:stream')
        {
            $heap->sid($node->getAttribute('id'));
            $kernel->yield('set_auth');
            $kernel->post($heap->events(), +PCJ_AUTHNEGOTIATE);
        
        }
        when('iq') 
        {
            given([$node->getAttribute('type'), $node->getAttribute('id')])
            {
                when([+IQ_RESULT, 'AUTH'])
                {
                    $heap->relinquish_states();
                    $kernel->post($heap->events(), +PCJ_AUTHSUCCESS);
                    $kernel->post($heap->events(), +PCJ_READY);
                
                }
                when([+IQ_ERROR, 'AUTH']) {

                    $heap->debug_message('Authentication Failed');
                    $kernel->yield('shutdown');
                    $kernel->post($heap->events(), +PCJ_AUTHFAIL);
                }
            }
        }
    }

    return;
}

1;

__END__

=pod

=head1 NAME

POE::Component::Jabber::Legacy

=head1 SYNOPSIS

PCJ::Legacy is a Protocol implementation for the legacy (ie. Pre-XMPP) Jabber
protocol.

=head1 DESCRIPTION

PCJ::Legacy implements the simple iq:auth authentication mechanism defined in
the deprecated XEP at http://www.xmpp.org/extensions/xep-0078.html. This
Protocol class is mainly used for connecting to legacy jabber servers that do
not conform the to XMPP1.0 RFC.

=head1 METHODS

Please see PCJ::Protocol for what methods this class supports.

=head1 EVENTS

Listed below are the exported events that end up in PCJ's main session:

=over 2

=item set_auth

This handles construction and sending of the iq:auth query.

=item init_input_handler

This is our main entry point. This is used by PCJ to deliver all input events 
until we are finished. Also handles responses to authentication.

=back

=head1 NOTES AND BUGS

Ideally, this class wouldn't be necessary, but there is a large unmoving mass 
of entrenched users and administrators that refuse to migrate to XMPP. It
largely doesn't help that debian still ships jabberd 1.4.3 which does NOT 
support XMPP.

The underlying backend has changed this release to now use a new Node
implementation based on XML::LibXML::Element. Please see POE::Filter::XML::Node
documentation for the relevant API changes.

=head1 AUTHOR

Copyright (c) 2003-2009 Nicholas Perez. Distributed under the GPL.

=cut
