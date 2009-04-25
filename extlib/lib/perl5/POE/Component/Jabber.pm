package POE::Component::Jabber;
use warnings;
use strict;

use 5.010;
use POE;
use POE::Wheel::ReadWrite;
use POE::Wheel::SocketFactory;

use POE::Component::PubSub;

use POE::Component::Jabber::Events;
use POE::Component::Jabber::ProtocolFactory;

use POE::Filter::XML;
use POE::Filter::XML::Node;
use POE::Filter::XML::NS(':JABBER');

use Digest::MD5('md5_hex');
use Carp;

use constant 
{
    '_pcj_config'           =>  0,
    '_pcj_sock'             =>  1,
    '_pcj_sfwheel'          =>  2,
    '_pcj_wheel'            =>  3,
    '_pcj_id'               =>  4,
    '_pcj_sid'              =>  5,
    '_pcj_jid'              =>  6,
    '_pcj_helper'           =>  7,
    '_pcj_shutdown'         =>  8,
    '_pcj_parent'           =>  9,
    '_pcj_input'            =>  10,
    '_pcj_events'           =>  11,
    '_pcj_pending'          =>  12,
    '_pcj_queue'            =>  13,
    '_pcj_init_finished'    =>  14,
    '_pcj_xpathfilters'     =>  15,
    'EVENT'                 =>  0,
    'EXPRESSION'            =>  1,

};

use base('Exporter');
our @EXPORT = qw/ JABBERD14_COMPONENT JABBERD20_COMPONENT LEGACY XMPP 
    PCJ_CONNECT PCJ_CONNECTING PCJ_CONNECTED PCJ_STREAMSTART
    PCJ_SSLNEGOTIATE PCJ_SSLSUCCESS PCJ_AUTHNEGOTIATE PCJ_AUTHSUCCESS
    PCJ_BINDNEGOTIATE PCJ_BINDSUCCESS PCJ_SESSIONNEGOTIATE PCJ_SESSIONSUCCESS
    PCJ_RECONNECT PCJ_NODESENT PCJ_NODERECEIVED PCJ_NODEQUEUED PCJ_RTS_START
    PCJ_RTS_FINISH PCJ_READY PCJ_STREAMEND PCJ_SHUTDOWN_START
    PCJ_SHUTDOWN_FINISH PCJ_SOCKETFAIL PCJ_SOCKETDISCONNECT PCJ_AUTHFAIL
    PCJ_BINDFAIL PCJ_SESSIONFAIL PCJ_SSLFAIL PCJ_CONNECTFAIL PCJ_XPATHFILTER /;

our $VERSION = '3.00';

sub new()
{
    my $class = shift;
    my $self = [];
    $self->[+_pcj_pending] = {};

    bless($self, $class);

    my $me = $class . '->new()';
    Carp::confess "$me requires an even number of arguments" if(@_ & 1);
    
    $self->_gather_options(\@_);
    
    my $args = $self->[+_pcj_config];

    $self->[+_pcj_helper] =
        POE::Component::Jabber::ProtocolFactory::get_guts
        (
            $args->{'connectiontype'}
        );

    $args->{'version'}      ||= $self->[+_pcj_helper]->get_version();
    $args->{'xmlns'}        ||= $self->[+_pcj_helper]->get_xmlns();
    $args->{'alias'}        ||= 'POE_COMPONENT_JABBER';
    $args->{'stream'}       ||= +XMLNS_STREAM;
    $args->{'debug'}        ||= 0 ;
    $args->{'resource'}     ||= md5_hex(time().rand().$$.rand().$^T.rand());
    
    $self->[+_pcj_events] = $args->{'alias'};

    Carp::confess "$me requires ConnectionType to be defined" if not defined
        $args->{'connectiontype'};
    Carp::confess "$me requires Username to be defined" if not defined
        $args->{'username'};
    Carp::confess "$me requires Password to be defined" if not defined
        $args->{'password'};
    Carp::confess "$me requires Hostname to be defined" if not defined
        $args->{'hostname'};
    Carp::confess "$me requires IP to be defined" if not defined
        $args->{'ip'};
    Carp::confess "$me requires Port to be defined" if not defined
        $args->{'port'};
    
    $POE::Component::PubSub::TRACE_AND_DEBUG = $args->{'debug'};
    POE::Component::PubSub->new($args->{'alias'});

    POE::Session->create
    (
        'object_states' =>
        [
            $self => 
            [
                '_start',
                'initiate_stream',
                'connect',
                '_connect',
                'connected',
                'disconnected',
                'shutdown',
                'output_handler',
                'debug_output_handler',
                'input_handler',
                'debug_input_handler',
                'return_to_sender',
                'connect_error',
                'server_error',
                'flushed',
                '_stop',
                'purge_queue',
                'debug_purge_queue',
                'xpath_filter',
                'halt',
            ],

            $self =>
            {
                'reconnect' => 'connect'
            },

            $self->[+_pcj_helper] => $self->[+_pcj_helper]->get_states(),

        ],
        
        'options' => 
        {
            'trace' => $args->{'debug'}, 
            'debug' => $args->{'debug'},
        },

        'heap' => $self,
    );


    return $self;

}

sub wheel()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_wheel] = $arg;

    } else {

        return shift(@_)->[+_pcj_wheel];
    }
}

sub sock()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_sock] = $arg;

    } else {

        return shift(@_)->[+_pcj_sock];
    }
}

sub config()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_config] = $arg;

    } else {

        return shift(@_)->[+_pcj_config];
    }
}

sub sid()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_sid] = $arg;
    
    } else {

        return shift(@_)->[+_pcj_sid];
    }
}

sub jid()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_jid] = $arg;
    
    } else {

        return shift(@_)->[+_pcj_jid];
    }
}

sub input()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_input] = $arg;

    } else {

        return shift(@_)->[+_pcj_input];
    }
}

sub events()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_events] = $arg;

    } else {

        return shift(@_)->[+_pcj_events];
    }
}

sub pending()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_pending] = $arg;
    
    } else {

        return shift(@_)->[+_pcj_pending];
    }
}

sub queue()
{
    if(@_ > 1)
    {
        my ($self, $arg) = @_;
        $self->[+_pcj_queue] = $arg;

    } else {

        return shift(@_)->[+_pcj_queue];
    }
}

sub _gather_options()
{
    my ($self, $args) = @_;
    
    my $opts = {};

    while(@$args != 0)
    {
        my $key = lc(shift(@{$args}));
        my $value = shift(@{$args});
        
        if(ref($value) eq 'HASH')
        {
            my $hash = {};
            foreach my $sub_key (keys %$value)
            {
                $hash->{lc($sub_key)} = $value->{$sub_key};
            }
            $opts->{$key} = $hash;
            next;
        }
        $opts->{$key} = $value;
    }

    $self->[+_pcj_config] = $opts;

    return $self;
}

sub connect_error()
{
    my ($kernel, $self, $call, $code, $err) = @_[KERNEL, OBJECT, ARG0..ARG2];

    $self->debug_message("Connect Error: $call: $code -> $err\n");

    $kernel->post($self->[+_pcj_events], +PCJ_CONNECTFAIL, $call, $code, $err);
    
    return;
}

sub _start()
{   
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $kernel->alias_set($self->[+_pcj_config]->{'alias'} . 'CORE');
    $self->_reset();

    if($self->[+_pcj_config]->{'debug'})
    {
        $kernel->state('output_handler', $self, 'debug_output_handler');
        $kernel->state('purge_queue', $self, 'debug_purge_queue');
    }

    $self->[+_pcj_queue] = [];
    $self->[+_pcj_xpathfilters] = [];
    
    my $pubsub = $self->[+_pcj_events];
    
    $kernel->call($pubsub, 'publish', +PCJ_SOCKETFAIL);
    $kernel->call($pubsub, 'publish', +PCJ_SOCKETDISCONNECT);
    $kernel->call($pubsub, 'publish', +PCJ_AUTHFAIL);
    $kernel->call($pubsub, 'publish', +PCJ_BINDFAIL);
    $kernel->call($pubsub, 'publish', +PCJ_SESSIONFAIL);
    $kernel->call($pubsub, 'publish', +PCJ_SSLFAIL);
    $kernel->call($pubsub, 'publish', +PCJ_CONNECTFAIL);
    $kernel->call($pubsub, 'publish', +PCJ_CONNECT);
    $kernel->call($pubsub, 'publish', +PCJ_CONNECTING);
    $kernel->call($pubsub, 'publish', +PCJ_CONNECTED);
    $kernel->call($pubsub, 'publish', +PCJ_SSLNEGOTIATE);
    $kernel->call($pubsub, 'publish', +PCJ_SSLSUCCESS);
    $kernel->call($pubsub, 'publish', +PCJ_AUTHNEGOTIATE);
    $kernel->call($pubsub, 'publish', +PCJ_AUTHSUCCESS);
    $kernel->call($pubsub, 'publish', +PCJ_BINDNEGOTIATE);
    $kernel->call($pubsub, 'publish', +PCJ_BINDSUCCESS);
    $kernel->call($pubsub, 'publish', +PCJ_SESSIONNEGOTIATE);
    $kernel->call($pubsub, 'publish', +PCJ_SESSIONSUCCESS);
    $kernel->call($pubsub, 'publish', +PCJ_NODESENT);
    $kernel->call($pubsub, 'publish', +PCJ_NODERECEIVED);
    $kernel->call($pubsub, 'publish', +PCJ_NODEQUEUED);
    $kernel->call($pubsub, 'publish', +PCJ_RTS_START);
    $kernel->call($pubsub, 'publish', +PCJ_RTS_FINISH);
    $kernel->call($pubsub, 'publish', +PCJ_READY);
    $kernel->call($pubsub, 'publish', +PCJ_STREAMEND);
    $kernel->call($pubsub, 'publish', +PCJ_STREAMSTART);
    $kernel->call($pubsub, 'publish', +PCJ_SHUTDOWN_START);
    $kernel->call($pubsub, 'publish', +PCJ_SHUTDOWN_FINISH);

    $kernel->call($pubsub, 'publish', 'output', 
        +PUBLISH_INPUT, 'output_handler');

    $kernel->call($pubsub, 'publish', 'return_to_sender', 
        +PUBLISH_INPUT, 'return_to_sender');

    $kernel->call($pubsub, 'publish', 'xpath_filter',
        +PUBLISH_INPUT, 'xpath_filter');

    $kernel->call($pubsub, 'publish', 'shutdown',
        +PUBLISH_INPUT, 'shutdown');
    
    $kernel->call($pubsub, 'publish', 'connect',
        +PUBLISH_INPUT, 'connect');

    $kernel->call($pubsub, 'publish', 'reconnect',
        +PUBLISH_INPUT, 'reconnect');

    $kernel->call($pubsub, 'publish', 'purge_queue',
        +PUBLISH_INPUT, 'purge_queue');

    $kernel->call($pubsub, 'publish', 'halt',
        +PUBLISH_INPUT, 'halt');
    return;
}

sub _stop()
{
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $kernel->alias_remove($_) for $kernel->alias_list();
    
    return;
}

sub halt()
{
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    
    $self->[+_pcj_wheel] = undef;
    $self->[+_pcj_sfwheel] = undef;
    $self->[+_pcj_sock]->close() if defined($self->[+_pcj_sock]);
    $self->[+_pcj_sock] = undef;
    $kernel->call($self->[+_pcj_events], 'destroy');
    $kernel->alias_remove($_) for $kernel->alias_list();

    return;
}


sub _reset()
{
    my $self = shift;
    
    $self->[+_pcj_sid] = 0;
    $self->[+_pcj_pending] = {};
    $self->[+_pcj_init_finished] = 0;
    $self->[+_pcj_id] ||= Digest::SHA1->new();
    $self->[+_pcj_id]->add(time().rand().$$.rand().$^T.rand());
    $self->[+_pcj_wheel] = undef;
    $self->[+_pcj_sfwheel] = undef;
    $self->[+_pcj_sock]->close() if defined($self->[+_pcj_sock]);
    $self->[+_pcj_sock] = undef;
    return;
}

sub connect()
{
    my ($kernel, $self, $ip, $port) = @_[KERNEL, OBJECT, ARG0, ARG1];
    
    $self->[+_pcj_config]->{'ip'} = $ip if defined $ip;
    $self->[+_pcj_config]->{'port'} = $port if defined $port;

    $self->_reset();
    $kernel->yield('_connect');

    $kernel->post($self->[+_pcj_events], +PCJ_CONNECT);
    return;
}

sub _connect()
{
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    
    $self->[+_pcj_sfwheel] = POE::Wheel::SocketFactory->new
        (
            'RemoteAddress'     =>  $self->[+_pcj_config]->{'ip'},
            'RemotePort'        =>  $self->[+_pcj_config]->{'port'},
            'SuccessEvent'      =>  'connected',
            'FailureEvent'      =>  'connect_error',
        );
    
    
    $kernel->post($self->[+_pcj_events], +PCJ_CONNECTING);
    
    return;

}

sub _default()
{
    my ($event) = $_[ARG0];

    $_[OBJECT]->debug_message($event . ' was not caught');
}

sub return_to_sender()
{
    my ($kernel, $self, $session, $sender, $event, $node) = 
        @_[KERNEL, OBJECT, SESSION, SENDER, ARG0, ARG1];
    
    my $attrs = $node->getAttributes();
    my $pid;
    
    if(exists($attrs->{'id'}))
    {
        if(exists($self->[+_pcj_pending]->{$attrs->{'id'}}))
        {
            $self->debug_message('OVERRIDING USER DEFINED ID!');
            
            $pid = $self->[+_pcj_id]->add(
                $self->[+_pcj_id]->clone()->hexdigest())
                    ->clone()->hexdigest();

            $node->setAttribute('id', $pid);
        }

        $pid = $attrs->{'id'};
        
    } else {
        
        $pid = $self->[+_pcj_id]->add(
            $self->[+_pcj_id]->clone()->hexdigest())
                ->clone()->hexdigest();
        
        $node->setAttribute('id', $pid);
    }
    
    my $state = $session == $sender ? 1 : undef;
    $self->[+_pcj_pending]->{$pid} = [];
    $self->[+_pcj_pending]->{$pid}->[0] = $sender->ID();
    $self->[+_pcj_pending]->{$pid}->[1] = $event;

    $kernel->call($self->[+_pcj_events], 'publish', $event) if defined($state);
    
    $kernel->yield('output_handler', $node, $state);

    $kernel->post($self->[+_pcj_events], +PCJ_RTS_START, $node);
    
    return;

}

sub connected()
{
    my ($kernel, $self, $sock) = @_[KERNEL, OBJECT, ARG0];

    $self->[+_pcj_sock] = $sock;
    $self->[+_pcj_sfwheel] = undef;

    my $input = $self->[+_pcj_helper]->get_input_event() || 
        Carp::confess('No input event defined in helper!');
    my $error = $self->[+_pcj_helper]->get_error_event();
    my $flushed = $self->[+_pcj_helper]->get_flushed_event();
    
    $kernel->state('input_handler', $self->[+_pcj_helper], $input);
    $kernel->state('server_error', $self->[+_pcj_helper], $error) if $error;
    $kernel->state('flushed', $self->[+_pcj_helper], $flushed) if $flushed;

    $self->[+_pcj_wheel] = POE::Wheel::ReadWrite->new
    (
        'Handle'        => $self->[+_pcj_sock],
        'Filter'        => POE::Filter::XML->new(),
        'InputEvent'    => 'input_handler',
        'ErrorEvent'    => 'server_error',
        'FlushedEvent'    => 'flushed',
    );

    $kernel->yield('initiate_stream');

    $kernel->post($self->[+_pcj_events], +PCJ_CONNECTED);
    
    return;
}

sub relinquish_states()
{
    my $self = shift;
    
    if($self->[+_pcj_config]->{'debug'})
    {
        $poe_kernel->state('input_handler', $self, 'debug_input_handler');

    } else {
        
        $poe_kernel->state('input_handler', $self, 'input_handler');
    }
    
    $poe_kernel->state('server_error', $self, 'server_error');
    $poe_kernel->state('flushed', $self, 'flushed');

    $self->[+_pcj_init_finished] = 1;
    return;
}

sub initiate_stream()
{
    my ($kernel, $self, $sender, $session) = 
        @_[KERNEL, OBJECT, SENDER, SESSION];

    my $element = POE::Filter::XML::Node->new('stream:stream');
    $element->setAttributes
    (    
        [
            'to', $self->[+_pcj_config]->{'hostname'}, 
            'xmlns', $self->[+_pcj_config]->{'xmlns'}, 
            'xmlns:stream', $self->[+_pcj_config]->{'stream'}, 
            'version', $self->[+_pcj_config]->{'version'}
        ]
    );
    $element->stream_start(1);
    
    my $state = $session == $sender ? 1 : undef;
    $kernel->yield('output_handler', $element, $state);

    $kernel->post($self->[+_pcj_events], +PCJ_STREAMSTART, $element);
    
    return;
}

sub disconnected()
{    
    my ($kernel, $self) = @_[KERNEL, OBJECT];
    $kernel->post($self->[+_pcj_events], +PCJ_SOCKETDISCONNECT);
    return;
}

sub flushed()
{
    my ($kernel, $self, $session) = @_[KERNEL, OBJECT, SESSION];

    if($self->[+_pcj_shutdown])
    {
        $kernel->call($session, 'disconnected');
        $kernel->post($self->[+_pcj_events], +PCJ_SHUTDOWN_FINISH);
    }
    
    return;
}
    

sub shutdown()
{
    my ($kernel, $self) = @_[KERNEL, OBJECT];

    if(defined($self->[+_pcj_wheel]))
    {
        my $node = POE::Filter::XML::Node->new('stream:stream');
        $node->stream_end(1);
        
        $self->[+_pcj_shutdown] = 1;

        $self->[+_pcj_wheel]->put($node);

        $kernel->post($self->[+_pcj_events], +PCJ_STREAMEND);
        $kernel->post($self->[+_pcj_events], +PCJ_SHUTDOWN_START);
    }
    return;
}

sub debug_purge_queue()
{
    my ($kernel, $self, $sender, $session) = 
        @_[KERNEL, OBJECT, SENDER, SESSION];
    
    my $items = [];

    while(my $item = shift(@{$self->[+_pcj_queue]}))
    {
        push(@$items, $item);
    }
    
    $self->debug_message( 'Items pulled from queue: ' . scalar(@$items));
    
    my $state = $sender == $session ? 1 : undef;

    foreach(@$items)
    {    
        $kernel->yield('output_handler', $_, $state);
    }

    return;
}

sub purge_queue()
{
    my ($kernel, $self, $sender, $session) =
        @_[KERNEL, OBJECT, SENDER, SESSION];
    
    my $items = [];

    while(my $item = shift(@{$self->[+_pcj_queue]}))
    {
        push(@$items, $item);
    }
    
    my $state = $sender == $session ? 1 : undef;

    foreach(@$items)
    {
        $kernel->yield('output_handler', $_, $state);
    }
    
    return;
}


sub debug_output_handler()
{
    my ($kernel, $self, $node, $state) = @_[KERNEL, OBJECT, ARG0, ARG1];

    if(defined($self->[+_pcj_wheel]))
    {
        if($self->[+_pcj_init_finished] || $state)
        {    
            $self->debug_message('Sent: ' . $node->toString());
            $self->[+_pcj_wheel]->put($node);
            $kernel->post($self->[+_pcj_events], +PCJ_NODESENT, $node);

        } else {
            
            $self->debug_message('Still initialising.');
            $self->debug_message('Queued: ' . $node->toString());
            push(@{$self->[+_pcj_queue]}, $node);
            $self->debug_message(
                'Queued COUNT: ' . scalar(@{$self->[+_pcj_queue]}));
            $kernel->post($self->[+_pcj_events], +PCJ_NODEQUEUED, $node);
        }

    } else {
        
        $self->debug_message('There is no wheel present.');
        $self->debug_message('Queued: ' . $node->toString());
        $self->debug_message(
            'Queued COUNT: ' . scalar(@{$self->[+_pcj_queue]}));
        push(@{$self->[+_pcj_queue]}, $node);
        $kernel->post($self->[+_pcj_events], +PCJ_SOCKETDISCONNECT);
        $kernel->post($self->[+_pcj_events], +PCJ_NODEQUEUED, $node);
    }
    
    return;
}

sub output_handler()
{
    my ($kernel, $self, $node, $state) = @_[KERNEL, OBJECT, ARG0, ARG1];

    if(defined($self->[+_pcj_wheel]))
    {
        if($self->[+_pcj_init_finished] || $state)
        {
            $self->[+_pcj_wheel]->put($node);
            $kernel->post($self->[+_pcj_events], +PCJ_NODESENT, $node);
        
        } else {

            push(@{$self->[+_pcj_queue]}, $node);
            $kernel->post($self->[+_pcj_events], +PCJ_NODEQUEUED, $node);
        }

    } else {

        push(@{$self->[+_pcj_queue]}, $node);
        $kernel->post($self->[+_pcj_events], +PCJ_SOCKETDISCONNECT);
        $kernel->post($self->[+_pcj_events], +PCJ_NODEQUEUED, $node);
    }
    return;
}

sub input_handler()
{
    my ($kernel, $self, $node) = @_[KERNEL, OBJECT, ARG0];
    
    my $attrs = $node->getAttributes();        
    
    if(exists($attrs->{'id'}))
    {
        if(defined($self->[+_pcj_pending]->{$attrs->{'id'}}))
        {
            my $array = delete $self->[+_pcj_pending]->{$attrs->{'id'}};
            $kernel->post($array->[0], $array->[1], $node);
            $kernel->post($self->[+_pcj_events], 'rescind', $array->[1]) 
                if $array->[0] != $_[SESSION]->ID();
            $kernel->post($self->[+_pcj_events], +PCJ_RTS_FINISH, $node);
            return;
        }
    }

    for(0..$#{$self->[+_pcj_xpathfilters]})
    {
        my $nodes = 
        [
            map { ordain($_) } $node->findnodes($self->[+_pcj_xpathfilters]->[$_]->[+EXPRESSION])
        ];

        if(@$nodes)
        {
            $kernel->post
            (
                $self->[+_pcj_events], 
                $self->[+_pcj_xpathfilters]->[$_]->[+EVENT],
                $self->[+_pcj_xpathfilters]->[$_]->[+EXPRESSION],
                $nodes,
                $node
            );
        }
    }

    $kernel->post($self->[+_pcj_events], +PCJ_NODERECEIVED, $node);

    return;
}

sub debug_input_handler()
{
    my ($kernel, $self, $node) = @_[KERNEL, OBJECT, ARG0];

    $self->debug_message("Recd: ".$node->toString());

    my $attrs = $node->getAttributes();

    if(exists($attrs->{'id'}))
    {
        if(defined($self->[+_pcj_pending]->{$attrs->{'id'}}))
        {
            my $array = delete $self->[+_pcj_pending]->{$attrs->{'id'}};
            $kernel->post($array->[0], $array->[1], $node);
            $kernel->post($self->[+_pcj_events], 'rescind', $array->[1]) 
                if $array->[0] != $_[SESSION]->ID();
            $kernel->post($self->[+_pcj_events], +PCJ_RTS_FINISH, $node);
            return;
        }
    }
    
    for(0..$#{$self->[+_pcj_xpathfilters]})
    {
        my $nodes = 
        [
            map { ordain($_) } $node->findnodes($self->[+_pcj_xpathfilters]->[$_]->[+EXPRESSION])
        ];

        if(@$nodes)
        {
            $self->debug_message('XPATH Match: '.$self->[+_pcj_xpathfilters]->[$_]->[+EXPRESSION]);
            
            for(0..$#{$nodes})
            {
                $self->debug_message('XPATH Matched Node: '.$nodes->[$_]);
            }

            $kernel->post
            (
                $self->[+_pcj_events], 
                $self->[+_pcj_xpathfilters]->[$_]->[+EVENT],
                $self->[+_pcj_xpathfilters]->[$_]->[+EXPRESSION],
                $nodes,
                $node
            );
        }
    }
    
    $kernel->post($self->[+_pcj_events], +PCJ_NODERECEIVED, $node);
    return;
}

sub xpath_filter()
{
    my ($kernel, $self, $cmd, $event, $xpath) = 
        @_[KERNEL, OBJECT, ARG0, ARG1, ARG2];

    given($cmd)
    {
        when('add')
        {
            push(@{$self->[+_pcj_xpathfilters]}, [$event, $xpath]);
            
            $kernel->post
            (
                $self->[+_pcj_events],
                'publish',
                $event
            );
        }

        when('remove')
        {
            @{$self->[+_pcj_xpathfilters]} = grep { $_->[+EVENT] ne $event } @{$self->[+_pcj_xpathfilters]};
            $kernel->post
            (
                $self->[+_pcj_events],
                'recind',
                $event
            );
        }
    }
}

sub server_error()
{
    my ($kernel, $self, $call, $code, $err) = @_[KERNEL, OBJECT, ARG0..ARG2];
    
    $self->[+_pcj_wheel] = undef;

    $kernel->post($self->[+_pcj_events], +PCJ_SOCKETFAIL, $call, $code, $err);
    return;
}

sub debug_message()
{    
    my $self = shift;
    warn "\n", scalar (localtime (time)), ': ' . shift(@_) ."\n";

    return;
}

1;

__END__

=pod

=head1 NAME

POE::Component::Jabber - A POE Component for communicating over Jabber

=head1 VERSION

3.00

=head1 DESCRIPTION

PCJ is a communications component that fits within the POE framework and
provides the raw low level footwork of initiating a connection, negotiatating
various protocol layers, and authentication necessary for the end developer
to focus more on the business end of implementing a client or service.

=head1 METHODS

=over 4

=item new()

Accepts many named, required arguments which are listed below. new() will
return a reference to the newly created reference to a PCJ object and should
be stored. There are many useful methods that can be called on the object to
gather various bits of information such as your negotiated JID.

=over 2

=item IP

The IP address in dotted quad, or the FQDN for the server.

=item PORT

The remote port of the server to connect.

=item HOSTNAME

The hostname of the server. Used in addressing.

=item USERNAME

The username to be used in authentication (OPTIONAL for jabberd14 service
connections).

=item PASSWORD

The password to be used in authentication.

=item RESOURCE

The resource that will be used for binding and session establishment 
(OPTIONAL: resources aren't necessary for initialization of service oriented
connections, and if not provided for client connections will be automagically 
generated).

=item ALIAS

The alias the component should register for use within POE. Defaults to
the class name.

=item CONNECTIONTYPE

This is the type of connection you wish to esablish. There four possible types
available for use. One must be selected. Each item is exported by default.

=over 2

=item XMPP (XMPP.pm)

This connection type is for use with XMPP 1.0 compliant servers. It implements
all of the necessary functionality for TLS, binding, and session negotiation.

=item LEGACY (Legacy.pm)

LEGACY is for use with pre-XMPP Jabber servers. It uses the old style
authentication and non-secured socket communication.

=item JABBERD14_COMPONENT (J14.pm)

Use this connection type if designing a backbone level component for a server
that implements XEP-114 for router level communication.

=item JABBERD20_COMPONENT (J2.pm)

If making a router level connection to the jabberd2 server, use this
connection type. It implements the modified XMPP protocol, which does most of
it except the session negotiation.

=back

Each connection type has a corresponding module. See their respective
documentation for more information each protocol dialect.

=item VERSION

If for whatever reason you want to override the protocol version gathered from
your ConnectionType, this is the place to do it. Please understand that this 
value SHOULD NOT be altered, but it is documented here just in case.

=item XMLNS

If for whatever reason you want to override the protocol's default XML
namespace that is gathered from your ConnectionType, use this variable. Please
understand that this value SHOULD NOT be altered, but is documented here just
in case.

=item STREAM

If for whatever reason you want to override the xmlns:stream attribute in the
<stream:stream/> this is the argument to use. This SHOULD NOT ever need to be
altered, but it is available and documented just in case.

=item DEBUG

If bool true, will enable debugging and tracing within the component. All XML
sent or received through the component will be printed to STDERR

=back

=item wheel() [Protected]

wheel() returns the currently stored POE::Wheel reference. If provided an
argument, that argument will replace the current POE::Wheel stored.

=item sock() [Protected]

sock() returns the current socket being used for communication. If provided an
argument, that argument will replace the current socket stored.

=item sid() [Protected]

sid() returns the session ID that was given by the server upon the initial
connection. If provided an argument, that argument will replace the current 
session id stored.

=item config() [Protected]

config() returns the configuration structure (HASH reference) of PCJ that is 
used internally. It contains values that are either defaults or were 
calculated based on arguments provided in the constructor. If provided an 
argument, that argument will replace the current configuration.

=item pending() [Protected]

pending() returns a hash reference to the currently pending return_to_sender
transactions keyed by the 'id' attribute of the XML node. If provided an
argument, that argument will replace the pending queue.

=item queue() [Protected]

queue() returns an array reference containing the Nodes sent when there was 
no suitable initialized connection available. Index zero is the first Node
placed into the queue with index one being the second, and so on. See under
the EVENTS section, 'purge_queue' for more information.

=item _reset() [Private]

_reset() returns PCJ back to its initial state and returns nothing.

=item _gather_options() [Private]

_gather_options() takes an array reference of the arguments provided to new()
(ie. \@_) and populates its internal configuration with the values (the same 
configuration returned by config()).

=item relinquish_states() [Protected]

relinquish_states() is used by Protocol subclasses to return control of the
events back to the core of PCJ. It is typically called when the event 
PCJ_READY is fired to the events handler.

=back

=head1 PUBLISHED INPUT EVENTS

=over 4

=item 'output'

This is the event that you use to push data over the wire. It accepts only one
argument, a reference to a POE::Filter::XML::Node.

=item 'return_to_sender'

This event takes (1) a POE::Filter::XML::Node and gives it a unique id, and 
(2) a return event and places it in the state machine. Upon receipt of 
response to the request, the return event is fired with the response packet.

POE::Component::Jabber will publish the return event upon receipt, and rescind
the event once the the return event is fired.

In the context POE::Component::PubSub, this means that a subscription must 
exist to the return event. Subscriptions can be made prior to publishing.

Please note that return_to_sender short circuits before XPATH filter and normal
node received events.

=item 'xpath_filter'

This event takes (1) a command of either 'add' or 'remove', (2) and event name
to be called upon a successful match, and (3) an XPATH expression.

With 'add', all three arguments are required. With 'remove', only the event 
name is required.

Like return_to_sender, POE::Component::Jabber will publish the return event
upon receipt, but will NOT rescind once the filter matches something. This
allows for persistent filters and event dispatching. 

Every filter is evaluated for every packet (if not applicable to 
return_to_sender processing), allowing multiple overlapping filters. And event 
names are not checked to be unique, so be careful when adding filters that go 
to the same event, because 'remove' will remove all instances of that 
particular event.

=item 'shutdown'

The shutdown event terminates the XML stream which in turn will trigger the
end of the socket's life.

=item 'connect' and 'reconnect'

This event can take (1) the ip address of a new server and (2) the port. This
event may also be called without any arguments and it will force the component
to [re]connect.

This event must be posted before the component will initiate a connection.

=item 'purge_queue'

If Nodes are sent to the output event when there isn't a fully initialized
connection, the Nodes are placed into a queue. PCJ will not automatically purge
this queue when a suitable connection DOES become available because there is no
way to tell if the packets are still valid or not. It is up to the end 
developer to decide this and fire this event. Packets will be sent in the order
in which they were received.

=back

=head1 PUBLISHED OUTPUT EVENTS

Please see POE::Component::Jabber::Events for a list of published events to
which subscriptions can be made. 

=head1 CHANGES

From the 2.X branch, several changes have been made improve event
management. 

The guts are now based around POE::Component::PubSub. This enables very 
specific subscriptions to status events rather than all of the status 
events being delivered to a single event.

Also, using the new POE::Filter::XML means that the underlying XML parser 
and Node implementation has changed for the better but also introduced
API incompatibilities. For the most part, a simple search-and-replace 
will suffice. Well worth it for the power to apply XPATH expressions to
nodes.

=head1 NOTES

This is a connection broker. This should not be considered a first class
client or service. This broker basically implements whatever core
functionality is required to get the end developer to the point of writing
upper level functionality quickly. 

=head1 EXAMPLES

For example implementations using all four current aspects, please see the 
examples/ directory in the distribution.

=head1 AUTHOR

Copyright (c) 2003-2009 Nicholas Perez. Distributed under the GPL.

=cut

