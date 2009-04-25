package POE::Component::Jabber::Protocol;
use warnings;
use strict;

our $VERSION = '3.00';

sub new() 
{
	my $class = shift(@_);
	return bless({}, $class);
}

sub get_version()
{
	return undef;
}

sub get_xmlns()
{
	return undef;
}

sub get_states()
{
	return undef;
}

sub get_input_event()
{
	return undef;
}

sub get_error_event()
{
	return undef;
}

sub get_flushed_event()
{
	return undef;
}

1;

__END__

=pod

=head1 NAME

POE::Component::Jabber::Protocol - A base class for implementing protocol
differences

=head1 SYNOPSIS

Inherit from this base class when implementing specifc protocol extentions that
may exist when writing to support various other jabber server implementations.

=head1 DESCRIPTION

PCJ::Protocol is the base class used when differences between authentication
or other connection initialization methods require special processing.

A prime example is JABBER(tm) vs. XMPP. The Jabber protocol uses a much
different method to authenticate (ie. using the iq:auth namespace) than XMPP
which uses SASL. While the rest of the protocol is substantially unchanged, 
these differences mean they must be accounted. In the 1.x versions of PCJ,
this was solved by having different duplicate classes in the same domain with
these differences manifest. It led to lots of headaches if there was a problem
because it then needed to be fixed in four places.

The solution is to keep the core aspect of PCJ immutable, while loading
separate individual Protocol classes that then implement the details for each
specific dialect.

As an end developer, if you wish to add support for another dialect (ie.
support another jabber server implementation that does service management
differently), subclass from this module and then add your entry into the 
ProtocolFactory.

Also be aware that PCJ uses object_states to construct its own session. 
Protocol subclassees are expected to fit smoothly into that. See the METHOD
get_states() for more information.

And remember when you are finished handling the protocol specifics and the 
connection is finished, fire off the PCJ_INIT_FINISHED status, and call 
relinquish_states() from the $_[HEAP] object to return control back to the PCJ
Core. (Yes, you read that correctly, $_[HEAP] is actually the PCJ object).

If in doubt, please see the source code for the other Protocol subclasses (ie. 
XMPP.pm, J14.pm, etc).

=head1 METHODS

At a bare minimum, some methods must be implemented by the end developer. These
will be indicated with a MANDATORY flag.

=over 4

=item new() [OPTIONAL]

new() provides a default constructor. It returns a hash reference blessed into
the provided class

=item get_version() [MANDATORY]

get_version() is used by PCJ to populate the 'version' attribute in the opening
<stream:stream/>. For XMPP enabled clients, this must return '1.0'. For legacy
Jabber connections, it should return '0.9' but it isn't required. For all other
applications, see the appropriate RFC for details on what version it expects.

=item get_xmlns() [MANDATORY]

get_xmlns() is used by PCJ to populate the default XML namespace attribute in 
the opening <stream:stream/>. Please feel free to use the constants in
POE::Filter::XML::NS to provide this.

=item get_states() [MANDATORY]

get_states is used by PCJ to fill its object_states with the Protocol states.
An array reference containing event names should be returned that corespond
one-to-one with the methods you implement in your subclass. Or if a mapping is
required, a hash reference should be returned that includes the mapping. See
POE::Session for more detail on object_states.

=item get_input_event() [MANDATORY]

get_input_event() returns the main entry point event into the Protocol 
subclass. This is then used by PCJ to assign the event to the Wheel, so that
the Protocol's events get fired from Wheel events.

=item get_error_event() [OPTIONAL]

get_error_event() returns the event to be called when an error occurs in the 
Wheel. Typically, this isn't required for Protocol subclasses, but is available
if needed.

=item get_flushed_event() [OPTIONAL]

get_flushed_event() returns the event to be called when the flushed event 
occurs in the Wheel. Typically, this isn't required for Protocol subclasses,
but is available if needed.

=back

=head1 NOTES

Here are some quick tips to keep in mind when subclassing:

Protocol subclassees execute within the same Session space as PCJ
$_[HEAP] contains the PCJ object.
If you need storage space, use $_[OBJECT] (ie. yourself).
Send status events. See PCJ::Status
Don't forget to send PCJ_READY.
And don't forget to call $_[HEAP]->relinquish_states() when finished.
When in doubt, use the source!

=head1 AUTHOR

Copyright (c) 2007-2009 Nicholas Perez. Distributed under the GPL.

=cut


