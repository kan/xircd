package XIRCD::Server;
use Any::Moose;
use XIRCD::Base;

use Encode;

use XIRCD::Component '-nocomponent';
use POE qw/Component::Server::IRC/;

has 'ircd' => (
    isa => 'POE::Component::Server::IRC',
    is  => 'rw',
);

has 'ircd_option' => (
    isa => 'HashRef',
    is  => 'rw',
    default => sub { {} },
);

has 'servername' => (
    isa => 'Str',
    is  => 'rw',
    default => sub { 'xircd' },
);

has 'server_nick' => (
    isa => 'Str',
    is  => 'rw',
    default => sub { 'xircd' },
);

has 'port' => (
    isa => 'Int',
    is  => 'rw',
    default => sub { 6667 },
);

has 'client_encoding' => (
    isa => 'Str',
    is  => 'rw',
    default => sub { 'utf-8' },
);

has auth => (
    isa => 'ArrayRef',
    is => 'rw',
    default => sub { [ {master => '*@*'} ] },
);

has 'nicknames' => (
    isa => 'HashRef',
    is  => 'rw',
    default => sub { {} },
);

has 'message_stack' => (
    isa => 'HashRef',
    is  => 'rw',
    default => sub { {} },
);

has 'joined' => (
    isa => 'HashRef',
    is  => 'rw',
    default => sub { {} },
);

has 'components' => (
    isa => 'HashRef',
    is  => 'rw',
    default => sub { {} },
);

sub START {
    my $self = shift;
    $self->alias('ircd');

    debug "start irc";

    my $ircd = POE::Component::Server::IRC->spawn(
        config => { servername => $self->servername, %{ $self->ircd_option } }
    );

    for my $auth (@{ $self->auth }) {
        $ircd->add_auth( %{$auth} );
    }
    $ircd->yield('register');
    $ircd->add_listener( port => $self->port );
    $ircd->yield( add_spoofed_nick => { nick => $self->server_nick } );

    debug "start server at localhost:" . $self->port . ' server nick is ' . $self->server_nick;

    $self->ircd($ircd);
}

event ircd_daemon_join => sub {
    my($user, $channel) = get_args;

    return unless my($nick) = $user =~ /^([^!]+)!/;
    return if self->nicknames->{$channel}->{$nick};
    return if $nick eq self->server_nick;

    self->joined->{$channel} = 1;

    for my $message ( @{ self->message_stack->{$channel} || [] } ) {
        self->ircd->yield( daemon_cmd_privmsg => $message->{nick}, $channel, $_ )
            for split /\r?\n/, $message->{text};
    }
    self->message_stack->{$channel} = [];
};

event ircd_daemon_quit => sub {
    my($user,) = get_args;

    return unless my($nick) = $user =~ /^([^!]+)!/;
    return if $nick eq self->server_nick;

    for my $channel ( keys %{self->joined} ) {
        next if self->nicknames->{$channel}->{$nick};
        self->joined->{$channel} = 0;
    }
};

event ircd_daemon_part => sub {
    my($user, $channel) = get_args;

    return unless my($nick) = $user =~ /^([^!]+)!/;
    return if self->nicknames->{$channel}->{$nick};
    return if $nick eq self->server_nick;

    self->joined->{$channel} = 0;
};

event ircd_daemon_public => sub {
    my($nick, $channel, $text) = get_args;

    debug "public [$channel] $nick : $text";

    my $component = self->components->{$channel};
    return unless $component;
    debug "send to $component";

    post $component => send_message => decode( self->client_encoding, $text );
};

event _publish_message => sub {
    my ($nick, $channel, $message) = get_args;

    debug "publish to irc: [$channel] $nick : $message";

    self->nicknames->{$channel} ||= {};
    if ($nick && !self->nicknames->{$channel}->{$nick}) {
        self->nicknames->{$channel}->{$nick}++;
        self->ircd->yield( add_spoofed_nick => { nick => $nick } );
        self->ircd->yield( daemon_cmd_join => $nick, $channel );
    }

    #$message = encode( self->client_encoding, $message );

    if ( self->joined->{$channel} ) {
        self->ircd->yield( daemon_cmd_privmsg => $nick => $channel, $_ )
            for split /\r?\n/, $message;
    } else {
        self->message_stack->{$channel} ||= [];
        push @{self->message_stack->{$channel}}, { nick => $nick, text => $message };
    }
};

event _publish_notice => sub {
    my ($channel, $message) = get_args;

    debug "notice to irc: [$channel] $message";

    #$message = encode( self->client_encoding, $message );

    self->ircd->yield( daemon_cmd_notice => self->server_nick => $channel, $_ )
        for split /\r?\n/, $message;
};

event join_channel => sub {
    my ($channel, $component) = get_args;

    debug "join channel: $channel";
    debug "register: $channel => $component";

    self->components->{$channel} = $component;
    self->ircd->yield( daemon_cmd_join => self->server_nick, $channel );
};

no Any::Moose;
__PACKAGE__->meta->make_immutable;
