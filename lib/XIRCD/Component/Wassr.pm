package XIRCD::Component::Wassr;
use MooseX::POE;

with 'MooseX::POE::Aliased';

use POE qw(
    Component::Jabber
    Component::Jabber::Error
    Component::Jabber::Status
    Component::Jabber::ProtocolFactory
    Filter::XML::Node
    Filter::XML::Utils
);
use POE::Filter::XML::NS qw/:JABBER :IQ/;

has 'config' => (
    isa => 'HashRef',
    is  => 'rw',
);

has 'jabber' => (
    isa     => 'POE::Component::Jabber',
    is      => 'rw',
);

has 'jid' => (
    isa     => 'Str',
    is      => 'rw',
);

sub debug(@) { ## no critic.
    print @_,"\n\n" if $ENV{XIRCD_DEBUG};
}

sub get_args(@) { ## no critic.
    return @_[9..19];
}

sub START {
    my $self = shift;

    $self->alias('wassr');

    debug "start wassr";

    my ($username, $hostname) = split '@', $self->config->{jabber}->{username};

    $self->jabber(
        POE::Component::Jabber->new(
            IP       => $self->config->{jabber}->{server},
            Port     => $self->config->{jabber}->{port} || 5222,
            Hostname => $hostname,
            Username => $username,
            Password => $self->config->{jabber}->{password},
            Alias    => 'jabber',
            States   => {
                StatusEvent => 'status_handler',
                InputEvent  => 'input_handler',
                ErrorEvent  => 'error_handler',
            },
            ConnectionType => +XMPP,
        )
    );

    POE::Kernel->post( ircd => 'join_channel', $self->config->{channel}, $self->alias );
    POE::Kernel->post( jabber => 'connect' );
}

event status_handler => sub {
    my $self = shift;
    my ($state,) = get_args(@_);

    if ($state == +PCJ_INIT_FINISHED) {
        debug "init finished";
        $self->jid($self->jabber->jid);

        POE::Kernel->post(jabber => 'output_handler', POE::Filter::XML::Node->new('presence'));
        POE::Kernel->post(jabber => 'purge_queue');
    }
};

event input_handler => sub {
    my $self = shift;
    my ($node,) = get_args(@_);

    debug "recv:", $node->to_str;

    my ($body,) = $node->get_tag('body');

    if ($body && $node->attr('from') =~ /^wassr-bot\@wassr\.jp/) {
        my ($nick, $text) = $body->data =~ /^([A-Za-z0-9_.-]+): (.*)/s;
        if ($nick && $text) {
            POE::Kernel->post( ircd => 'publish_message', $nick, $self->config->{channel}, $text );
        } else {
            POE::Kernel->post( ircd => 'publish_notice', $self->config->{channel}, $body->data );
        }
    }
};

event send_message => sub {
    my $self = shift;
    my ($message,) = get_args(@_);

    my $node = POE::Filter::XML::Node->new('message');

    $node->attr('to', 'wassr-bot@wassr.jp');
    $node->attr('from', $self->{jid} );
    $node->attr('type', 'chat');
    $node->insert_tag('body')->data( $message );

    debug "send:", $node->to_str;

    POE::Kernel->post( jabber => output_handler => $node );
};

event error_handler => sub {
    my $self = shift;
    my ($error,) = get_args(@_);

    if ( $error == +PCJ_SOCKETFAIL or $error == +PCJ_SOCKETDISCONNECT or $error == +PCJ_CONNECTFAIL ) {
        print "Reconnecting!\n";
        POE::Kernel->post( jabber => 'reconnect' );
    }
    elsif ( $error == +PCJ_SSLFAIL ) {
        print "TLS/SSL negotiation failed\n";
    }
    elsif ( $error == +PCJ_AUTHFAIL ) {
        print "Failed to authenticate\n";
    }
    elsif ( $error == +PCJ_BINDFAIL ) {
        print "Failed to bind a resource\n";
    }
    elsif ( $error == +PCJ_SESSIONFAIL ) {
        print "Failed to establish a session\n";
    }
};


1;
