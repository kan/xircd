package POE::Component::PubSub;

use 5.010;
use warnings;
use strict;
use base('Exporter');

our $VERSION = '0.05';

use POE;
use Carp;

use constant
{
	'EVENTS'		    => 0,
    'ALIAS'             => 1,
    'PUBLISHER'         => 0,
    'SUBSCRIBERS'       => 1,
    'TYPE'              => 2,
    'INPUT'             => 3,
    'PUBLISH_INPUT'     => 0,
    'PUBLISH_OUTPUT'    => 1,
};

our @EXPORT = qw/ PUBLISH_INPUT PUBLISH_OUTPUT /;

our $TRACE_AND_DEBUG = 0;

sub new()
{
	my $class = shift(@_);
    my $alias = shift(@_);
	my $self = [];
	$self->[+EVENTS] = {};
    $alias //= 'PUBLISH_SUBSCRIBE';

    $self->[+ALIAS] = $alias;

	bless($self, $class);

	POE::Session->create
	(
		'object_states' =>
		[
			$self =>
			[
				'_start',
				'_stop',
				'_default',
				'publish',
				'subscribe',
				'rescind',
                'cancel',
                'destroy',
			]
		],

		'options' =>
		{
			'trace'	=>	$TRACE_AND_DEBUG,
			'debug'	=>	$TRACE_AND_DEBUG,
		}
	);
    
    return $self;
}

sub _start()
{
    $_[KERNEL]->alias_set($_[OBJECT]->[+ALIAS]);
}

sub _stop()
{
    $_[KERNEL]->alias_remove($_) for $_[KERNEL]->alias_list();
}

sub _default()
{
    my ($kernel, $self, $sender, $event, $arg) = 
        @_[KERNEL, OBJECT, SENDER, ARG0, ARG1];
    
    if($self->_event_exists($event))
    {
        if($self->_is_output($event))
        {
            if(!$self->_owns($sender->ID(), $event))
            {
                Carp::carp("Event [ $event ] is not owned by Sender: " . $sender->ID()) if $TRACE_AND_DEBUG;
                return;
            }

            if(!$self->_has_subscribers($event))
            {
                Carp::carp('Event[ '.$event.' ] currently has no subscribers') if $TRACE_AND_DEBUG;
                return;
            }

            while (my ($subscriber, $return) = each %{ $self->_get_subs($event) })
            {
                if(!$self->_has_event($subscriber, $return))
                {
                    Carp::carp("$subscriber no longer has $return in their events") if $TRACE_AND_DEBUG;
                    $self->_remove_sub($subscriber, $event);
                }
                
                $kernel->post($subscriber, $return, @$arg);
            }
            return;
        }
        else
        {
            $kernel->post(
                $kernel->ID_id_to_session($self->_get_pub($event)), 
                $self->_get_input($event), 
                @$arg);
        }
    }
    else
    {
        Carp::carp('Event [ '. $event . ' ] does not currently exist') if $TRACE_AND_DEBUG;
        return;
    }
}

sub destroy()
{
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    $self->[+EVENTS] = undef;
    $kernel->alias_remove($_) for $kernel->alias_list();
}

sub listing()
{
    my ($kernel, $self, $sender, $return) = @_[KERNEL, OBJECT, SENDER, ARG1];

    if(!defined($return))
	{
		Carp::carp('$event argument is required for listing') if $TRACE_AND_DEBUG;
        return;
	}
    
    if(!$self->_has_event($sender, $return))
	{
	    Carp::carp($sender . ' must own the ' . $return . ' event') if $TRACE_AND_DEBUG;
        return;
	}

    my $events = $self->_all_published_events();

    $kernel->post($sender, $return, $events);
}

sub publish()
{
	my ($kernel, $self, $sender, $event, $type, $input) =
        @_[KERNEL, OBJECT, SENDER, ARG0, ARG1, ARG2];
		
	if(!defined($event))
	{
		Carp::carp('$event argument is required for publishing') if $TRACE_AND_DEBUG;
        return;
	}
    
    if($self->_event_exists($event))
    {
        if($self->_is_published($event))
        {
            Carp::carp('Event [ '. $event  .' ] already has a publisher') if $TRACE_AND_DEBUG;
            return;
        }
        
        if(defined($type) && $type == +PUBLISH_INPUT)
        {
            if(!$self->_has_event($sender, $input))
            {
                Carp::carp($sender . ' must own the ' . defined($input) ? $input : '' . ' event') if $TRACE_AND_DEBUG;
                return;
            }

            if($self->_is_output($event))
            {
                Carp::carp('Event [ '. $event  .' ] already has a subscriber and precludes publishing') if $TRACE_AND_DEBUG;
                return;
            }
        }
    }

    if(defined($type) && $type == +PUBLISH_INPUT)
    {
        if(!$self->_has_event($sender, $input))
        {
            Carp::carp($sender . ' must own the ' . defined($input) ? $input : '' . ' event') if $TRACE_AND_DEBUG;
            return;
        }
    }

	$self->_add_pub($sender->ID(), $event, $type, $input);
	
}

sub subscribe()
{
	my ($kernel, $self, $sender, $event, $return) = 
        @_[KERNEL, OBJECT, SENDER, ARG0, ARG1];

	if(!defined($event))
	{
		Carp::carp('$event argument is required for subscribing') if $TRACE_AND_DEBUG;
        return;
	}
    
    if($self->_event_exists($event))
    {
        if(!$self->_is_output($event))
        {
            Carp::carp('Event[ '.$event.' ] is not an output event') if $TRACE_AND_DEBUG;
            return;
        }

        if(!$self->_has_event($sender, $return))
        {
            Carp::carp($sender . ' must own the ' . $return . ' event') if $TRACE_AND_DEBUG;
            return;
        }
    }

    $self->_add_sub($sender->ID, $event, $return);
}

sub rescind()
{
    my ($kernel, $self, $sender, $event) = 
        @_[KERNEL, OBJECT, SENDER, ARG0];

    if(!defined($event))
	{
		Carp::carp('$event argument is required for rescinding') if $TRACE_AND_DEBUG;
        return;
	}
    
    if($self->_event_exists($event))
    {
        if(!$self->_is_published($event))
        {
            Carp::carp('Event[ '.$event.' ] is not published') if $TRACE_AND_DEBUG;
            return;
        }

        if(!$self->_owns($sender->ID(), $event))
        {
            Carp::carp('Event[ '.$event.' ] is not owned by $sender') if $TRACE_AND_DEBUG;
            return;
        }

        if($self->_has_subscribers($event))
        {
            Carp::carp('Event[ '.$event.' ] currently has subscribers, but removing anyway') if $TRACE_AND_DEBUG;
        }
        
        $self->_remove_pub($sender->ID(), $event);
    }
}

sub cancel()
{
    my ($kernel, $self, $sender, $event) = 
        @_[KERNEL, OBJECT, SENDER, ARG0];
    
    if(!defined($event))
	{
		Carp::carp('$event argument is required for canceling') if $TRACE_AND_DEBUG;
        return;
	}

    if($self->_event_exists($event))
    {
        if(!$self->_is_subscribed($sender->ID(), $event))
        {
            Carp::carp($sender . ' must be subscribed to the ' . $event . ' event') if $TRACE_AND_DEBUG;
            return;
        }

        $self->_remove_sub($sender->ID(), $event);
    }
}

# EVIL: We need to do some checking to make sure subscribers actually have the 
# events they claim to have. I didn't want to have a dependency on 
# POE::API::Peek and the subsequent Devel::Size, so I ripped out what concepts
# I needed to implement this.
sub _events()
{
	my ($self, $session) = @_;
	
	if(uc(ref($session)) =~ m/POE::SESSION/)
	{
		return [ keys( %{ $session->[ &POE::Session::SE_STATES() ] } ) ] ;
	
	} else {
		
		my $ref = $poe_kernel->ID_id_to_session($session);

		if(defined($ref))
		{
			return [ keys( %{ $ref->[ &POE::Session::SE_STATES() ] } ) ];
		
		} else {

			return undef;
		}
	}
}

sub _has_event()
{
	my ($self, $session, $event) = @_;

    return 0 if not defined($event);
    my $events = $self->_events( $session );

    if(defined($events))
    {
	    return scalar( grep( m/$event/, @{ $events } ) );
    }
    else
    {
        return 0;
    }
}

sub _event_exists()
{
    return exists($_[0]->[+EVENTS]->{$_[1]});
}

sub _is_output()
{
    my ($self, $event) = @_;
    return $self->[+EVENTS]->{$event}->[+TYPE] == +PUBLISH_OUTPUT;
}

sub _has_subscribers()
{
    my ($self, $event) = @_;
    return scalar( keys %{ $self->[+EVENTS]->{$event}->[+SUBSCRIBERS] } ) ;
}

sub _is_published()
{
    my ($self, $event) = @_;
    return defined($self->[+EVENTS]->{$event}->[+PUBLISHER]);
}

sub _is_subscribed()
{
    my ($self, $subscriber, $event) = @_;
    return 0 if not defined($subscriber);
    return exists($self->[+EVENTS]->{$event}->[+SUBSCRIBERS]->{$subscriber});
}

sub _owns()
{
    my ($self, $publisher, $event) = @_;
    return 0 if not defined($publisher);
    return 0 if not defined($self->[+EVENTS]->{$event}->[+PUBLISHER]);
    return $self->[+EVENTS]->{$event}->[+PUBLISHER] eq $publisher;
}

sub _add_pub()
{
    my ($self, $publisher, $event, $type, $input) = @_;
    if(!exists($self->[+EVENTS]->{$event}))
    {
        $self->[+EVENTS]->{$event} = [];
        $self->[+EVENTS]->{$event}->[+SUBSCRIBERS] = {};
    }
    $self->[+EVENTS]->{$event}->[+PUBLISHER] = $publisher;
    $self->[+EVENTS]->{$event}->[+TYPE] = $type // +PUBLISH_OUTPUT;
    $self->[+EVENTS]->{$event}->[+INPUT] = $input;
    return;
}

sub _add_sub()
{
    my ($self, $subscriber, $event, $return) = @_;
    if(!exists($self->[+EVENTS]->{$event}))
    {
        $self->[+EVENTS]->{$event} = [];
        $self->[+EVENTS]->{$event}->[+SUBSCRIBERS] = {};
    }
    $self->[+EVENTS]->{$event}->[+SUBSCRIBERS]->{$subscriber} = $return;
    $self->[+EVENTS]->{$event}->[+TYPE] = +PUBLISH_OUTPUT;
    return;
}

sub _del_sub()
{
    my ($self, $subscriber, $event) = @_;
    delete($self->[+EVENTS]->{$event}->[+SUBSCRIBERS]->{$subscriber});
    return;
}

sub _del_pub()
{
    my ($self, $publisher, $event) = @_;
    delete($self->[+EVENTS]->{$event});
    return;
}

sub _get_subs()
{
    my ($self, $event) = @_;
    return $self->[+EVENTS]->{$event}->[+SUBSCRIBERS];
}

sub _get_pub()
{
    my ($self, $event) = @_;
    return $self->[+EVENTS]->{$event}->[+PUBLISHER];
}

sub _get_input()
{
    my ($self, $event) = @_;
    return $self->[+EVENTS]->{$event}->[+INPUT];
}

sub _all_published_events()
{
    my ($self) = @_;
    return [ map { [$_, $self->[+EVENTS]->{$_}->[+INPUT]] } sort keys %{$self->[+EVENTS]} ];
}

1;

__END__

=pod

=head1 NAME

POE::Component::PubSub - A generic publish/subscribe POE::Component that 
enables POE::Sessions to publish events to which other POE::Sessions may 
subscribe.

=head1 VERSION

Version 0.04

=head1 SYNOPSIS

# Instantiate the publish/subscriber with the alias "pub"
POE::Component::PubSub->new('pub');

# Publish an event called "FOO". +PUBLISH_OUTPUT is actually optional.
$_[KERNEL]->post('pub', 'publish', 'FOO', +PUBLISH_OUTPUT);

# Elsewhere, subscribe to that event, giving it an event to call
# when the published event is fired.
$_[KERNEL]->post('pub', 'subscribe', 'FOO', 'FireThisEvent');

# Fire off the published event
$_[KERNEL]->post('pub', 'FOO');

# Publish an 'input' event
$_[KERNEL]->post('pub', 'publish', 'BAR', +PUBLISH_INPUT, 'MyInputEvent');

# Tear down the whole thing
$_[KERNEL]->post('pub', 'destroy');


=head1 EVENTS

All public events do some sanity checking to make sure of a couple of things
before allowing the events such as checking to make sure the posting session
actually owns the event it is publishing, or that the event passed as the
return event during subscription is owned by the sender. When one of those 
cases comes up, an error is carp'd, and the event returns without stopping
execution.

=over 4

=item 'publish'

This is the event to use to publish events. It accepts one argument, the event
to publish. The published event may not already be previously published. The
event may be completely arbitrary and does not require the publisher to
implement that event. Think of it as a name for a mailing list.

You can also publish an 'input' or inverse event. This allows for arbitrary
sessions to post to your event. In this case, you must supply the optional
published event type and the event to be called when the published event fires. 

There are two types: PUBLISH_INPUT and PUBLISH_OUTPUT. PUBLISH_OUPUT is implied
when no argument is supplied.

=item 'subscribe'

This is the event to use when subscribing to published events. It accepts two
arguments: 1) the published event, and 2) the event name of the subscriber to
be called when the published event is fired. The event doesn't need to be  
published prior to subscription to resolve chicken and egg problems in an async
environment. But, the sender must own and implement the return event.

=item 'rescind'

Use this event to stop publication of an event. It accepts one argument, the 
published event. The event must be published, and published by the sender of
the rescind event. If the published event has any subscribers, a warning will
be carp'd but execution will continue.

=item 'cancel'

Cancel subscriptions to events with this event. It accepts one argment, the
published event. The event must be published and the sender must be subscribed
to the event.

=item '_default'

After an event is published, the publisher may arbitrarily fire that event to
this component and the subscribers will be notified by calling their respective
return events with whatever arguments are passed by the publisher. The event 
must be published, owned by the publisher, and have subscribers for the event
to be propagated. If any of the subscribers no longer has a valid return event
their subscriptions will be cancelled and a warning will be carp'd.

=item 'listing'

To receive an array reference containing tuples of the event name, and the type
of the events that are currently published within the component, call this 
event. It accepts one argument, the return event to fire with the listing. The 
sender must own the return event.

=item 'destroy'

This event will simply destroy any of its current state and remove any and all
aliases this session may have picked up. This should free up the session for
garbage collection.

=back

=head1 CLASS METHODS

=over 4

=item POE::Component::PubSub->new($alias)

This is the constructor for the publish subscribe component. It instantiates
it's own session using the provided $alias argument to set its kernel alias. 
If no alias is provided, the default alias is 'PUBLISH_SUBSCRIBE'.

=back

=head1 DEBUGGING

=over 4

=item $POE::Component::PubSub::TRACE_AND_DEBUG

To enable debugging within the component at the POE::Session level and also
with various warnings, set this variable to logical true BEFORE calling new().

=back

=head1 NOTES

Right now this component is extremely simple, but thorough when it comes to 
checking the various requirements for publishing and subscribing. Currently, 
there is no mechanism to place meta-subscriptions to the events of the 
component itself. This feature is planned for the next release.

Also, to do some of the checking on whether subscribers own the return events,
some ideas were lifted from POE::API::Peek, and like that module, if there are
changes to the POE core, they may break this module. 

=head1 AUTHOR

Nicholas R. Perez, C<< <nperez at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-poe-component-pubsub at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-PubSub>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::PubSub

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-PubSub>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-PubSub>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-PubSub>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-PubSub>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008-2009 Nicholas R. Perez, all rights reserved.

This program is released under the following license: gpl

=cut

