package POE::Component::Jabber::Events;
use warnings;
use strict;

use constant
{
	'PCJ_CONNECT'			=> 'PCJ_CONNECT',
	'PCJ_CONNECTING'		=> 'PCJ_CONNECTING',
	'PCJ_CONNECTED'			=> 'PCJ_CONNECTED',
    'PCJ_CONNECTFAIL'       => 'PCJ_CONNECTFAIL',
	'PCJ_STREAMSTART'		=> 'PCJ_STEAMSTART',
	'PCJ_STREAMEND'			=> 'PCJ_STREAMEND',
	'PCJ_NODESENT'			=> 'PCJ_NODESENT',
	'PCJ_NODERECEIVED'		=> 'PCJ_NODERECEIVED',
	'PCJ_NODEQUEUED'		=> 'PCJ_NODEQUEUED',
	'PCJ_SSLNEGOTIATE'		=> 'PCJ_SSLNEGOTIATE',
	'PCJ_SSLSUCCESS'		=> 'PCJ_SSLSUCCESS',
    'PCJ_SSLFAIL'           => 'PCJ_SSLFAIL',
	'PCJ_AUTHNEGOTIATE'		=> 'PCJ_AUTHNEGOTIATE',
	'PCJ_AUTHSUCCESS'		=> 'PCJ_AUTHSUCCESS',
    'PCJ_AUTHFAIL'          => 'PCJ_AUTHFAIL',
	'PCJ_BINDNEGOTIATE'		=> 'PCJ_BINDNEGOTIATE',
	'PCJ_BINDSUCCESS'		=> 'PCJ_BINDSUCCESS',
    'PCJ_BINDFAIL'          => 'PCJ_BINDFAIL',
	'PCJ_SESSIONNEGOTIATE'	=> 'PCJ_SESSIONNEGOTIATE',
	'PCJ_SESSIONSUCCESS'	=> 'PCJ_SESSIONSUCCESS',
    'PCJ_SESSIONFAIL'       => 'PCJ_SESSIONFAIL',
	'PCJ_RTS_START'			=> 'PCJ_RTS_START',
	'PCJ_RTS_FINISH'		=> 'PCJ_RTS_FINISH',
	'PCJ_READY'     		=> 'PCJ_READY',
	'PCJ_SHUTDOWN_START'	=> 'PCJ_SHUTDOWN_START',
	'PCJ_SHUTDOWN_FINISH'	=> 'PCJ_SHUTDOWN_FINISH',
    'PCJ_SOCKETFAIL'        => 'PCJ_SOCKETFAIL',
    'PCJ_SOCKETDISCONNECT'  => 'PCJ_SOCKETDISCONNECT',
};

use base('Exporter');
our @EXPORT = qw/ PCJ_CONNECT PCJ_CONNECTING PCJ_CONNECTED PCJ_STREAMSTART 
	PCJ_SSLNEGOTIATE PCJ_SSLSUCCESS PCJ_AUTHNEGOTIATE PCJ_AUTHSUCCESS 
	PCJ_BINDNEGOTIATE PCJ_BINDSUCCESS PCJ_SESSIONNEGOTIATE PCJ_SESSIONSUCCESS 
	PCJ_NODESENT PCJ_NODERECEIVED PCJ_NODEQUEUED PCJ_RTS_START 
	PCJ_RTS_FINISH PCJ_READY PCJ_STREAMEND PCJ_SHUTDOWN_START
	PCJ_SHUTDOWN_FINISH PCJ_SOCKETFAIL PCJ_SOCKETDISCONNECT PCJ_AUTHFAIL 
    PCJ_BINDFAIL PCJ_SESSIONFAIL PCJ_SSLFAIL PCJ_CONNECTFAIL /;

our $VERSION = '3.00';
1;

__END__

=pod

=head1 NAME

POE::Component::Jabber::Events

=head1 SYNOPSIS

  PCJ_CONNECT
  PCJ_CONNECTING
  PCJ_CONNECTED
  PCJ_CONNECTFAIL
  PCJ_STREAMSTART
  PCJ_STREAMEND
  PCJ_NODESENT
  PCJ_NODERECEIVED
  PCJ_NODEQUEUED
  PCJ_SSLNEGOTIATE
  PCJ_SSLSUCCESS
  PCJ_SSLFAIL
  PCJ_AUTHNEGOTIATE
  PCJ_AUTHSUCCESS
  PCJ_AUTHFAIL
  PCJ_BINDNEGOTIATE
  PCJ_BINDSUCCESS
  PCJ_BINDFAIL
  PCJ_SESSIONNEGOTIATE
  PCJ_SESSIONSUCCESS
  PCJ_SESSIONFAIL
  PCJ_RTS_START
  PCJ_RTS_FINISH
  PCJ_READY
  PCJ_SHUTDOWN_START
  PCJ_SHUTDOWN_FINISH
  PCJ_SOCKETFAIL
  PCJ_SOCKETDISCONNECT

=head1 DESCRIPTION

POE::Component::Jabber::Events exports many useful constants for tracking the 
status of PCJ during its operation. Simply subscribe to these events in order
to receive notification.

=head1 EXPORTS

Below are the exported constants with a brief explanation of what it is 
signalling to the end developer:

=over 4

=item PCJ_CONNECT

'connect' or 'reconnect' event has fired.

=item PCJ_CONNECTING

Connecting is now in process

=item PCJ_CONNECTED

Initial connection established

=item PCJ_STREAMSTART

A <stream:stream/> tag has been sent. The number of these events is variable 
depending on which Protocol is currently active (ie. XMPP will send upto three, 
while LEGACY will only send one).

=item PCJ_SSLNEGOTIATE

TLS/SSL negotiation has begun.
This event only is fired from XMPP and JABBERD20_COMPONENT connections.

=item PCJ_SSLSUCCESS

TLS/SSL negotiation has successfully complete. Socket layer is now encrypted. 
This event only is fired from XMPP and JABBERD20_COMPONENT connections.

=item PCJ_SSLFAIL

TLS/SSL negotiation has failed.
This event only is fired from XMPP and JABBERD20_COMPONENT connections.

=item PCJ_AUTHNEGOTIATE

Whatever your authentication method (ie. iq:auth, SASL, <handshake/>, etc), it
is in process when this status is received.

=item PCJ_AUTHSUCCESS

Authentication was successful.

=item PCJ_AUTHFAIL

Authentication failed.

=item PCJ_BINDNEGOTIATE

For XMPP connections: this indicates resource binding negotiation has begun.

For JABBERD20_COMPONENT connections: domain binding negotiation has begun.

This event will not fire for any but the above two connection types.

=item PCJ_BINDSUCCESS

For XMPP connections: this indicates resource binding negotiation was 
sucessful.

For JABBERD20_COMPONENT connections: domain binding negotiation was successful.

This event will not fire for any but the above two connection types.

=item PCJ_BINDFAIL

Binding for which ever context has failed.

=item PCJ_SESSIONNEGOTIATE

Only for XMPP: This indicates session binding (XMPP IM) negotiation has begun.

=item PCJ_SESSIONSUCCESS

Only for XMPP: This indicates session binding (XMPP IM) negotiation was
successful.

=item PCJ_SESSIONFAIL

Session negotiation has failed for which ever context.

=item PCJ_NODESENT

A Node has been placed, outbound, into the Wheel. ARG0 will be the node.

=item PCJ_NODERECEIVED

A Node has been received. ARG0 will be the node.

=item PCJ_NODEQUEUED

An attempt to send a Node while there is no valid, initialized connection was 
caught. The Node has been queued. See POE::Component::Jabber event 
'purge_queue' for details. ARG0 will be the node.

=item PCJ_RTS_START

A return_to_sender event has been fired for an outbound node. ARG0 will be the
node.

=item PCJ_RTS_FINISH

A return_to_sender event has been fired for a matching inbound node. ARG0 will
be the node.

=item PCJ_READY

This event indicates that the connection is fully initialized and ready for use.

Watch for this event and begin packet transactions AFTER it has been fired.

=item PCJ_STREAMEND

A </stream:stream> Node has been sent. This indicates the end of the connection
and is called upon 'shutdown' of PCJ after the Node has been flushed.

=item PCJ_SHUTDOWN_START

This indicates that 'shutdown' has been fired and is currently in progress of 
tearing down the connection.

=item PCJ_SHUTDOWN_FINISH

This indicates that 'shutdown' is complete.

=item PCJ_SOCKETFAIL

This indicates a socket level error. ARG0..ARG2 will be exactly what was passed
to us from POE::Wheel::ReadWrite.

=item PCJ_SOCKETDISCONNECT

This indicates the socket has disconnected and will occur in both normal, and 
in error states.

=back

=head1 AUTHOR

(c) Copyright 2007-2009 Nicholas Perez. Released under the GPL.

=cut
