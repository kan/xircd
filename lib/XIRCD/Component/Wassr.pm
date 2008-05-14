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

sub debug(@) { ## no critic.
    print @_ if $ENV{XIRCD_DEBUG};
}

sub get_args(@) { ## no critic.
    return @_[9..19];
}

sub START {
    my $self = shift;

    $self->alias('jabber');

    debug "start wassr\n";

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

    POE::Kernel->post( ircd => 'join_channel', $self->config->{channel} );
    POE::Kernel->post( jabber => 'connect' );
}

event status_handler => sub {
    my $self = shift;
    my ($state,) = get_args(@_);

    if ($state == +PCJ_INIT_FINISHED) {
        debug "init finished\n";
        $self->jid($self->jabber->jid);
        #$heap->{sid} = $sender->ID;

        POE::Kernel->post(jabber => 'output_handler', POE::Filter::XML::Node->new('presence'));
        POE::Kernel->post(jabber => 'purge_queue');
    }
};

event input_handler => sub {
    my $self = shift;
    my ($node,) = get_args(@_);

    debug "recv:", $node->to_str, "\n\n";

    my ($body) = $node->get_tag('body');
    if ($body && $node->attr('from') =~ /^wassr-bot\@wassr\.jp/) {
        my ($nick, $text) = $body =~ /^(\w+): (.*)/s;
        POE::Kernel->post( ircd => 'publish_message', $nick, $self->config->{channel}, $text ) if $nick;
    }
};


1;
