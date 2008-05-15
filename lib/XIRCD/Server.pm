package XIRCD::Server;
use MooseX::POE;

with qw(MooseX::POE::Aliased);

use Clone qw/clone/;
use Encode;

use POE qw/Component::Server::IRC/;

has 'ircd' => (
    isa => 'POE::Component::Server::IRC',
    is  => 'rw',
);

has 'config' => (
    isa => 'HashRef',
    is  => 'rw',
);

has 'nicknames' => (
    isa => 'HashRef',
    is  => 'rw',
    default => sub { {} },
);

has 'components' => (
    isa => 'HashRef',
    is  => 'rw',
    default => sub { {} },
);

sub debug(@) { ## no critic.
    print @_, "\n\n" if $ENV{XIRCD_DEBUG};
}

sub get_args(@) { ## no critic.
    return @_[9..19];
}

sub START {
    my $self = shift;

    $self->alias('ircd');

    debug "start irc";

    $self->config->{servername} ||= 'xircd.ircd';
    $self->config->{client_encoding} ||= 'utf-8';

    $self->ircd(POE::Component::Server::IRC->spawn( config => clone($self->config) ));
    $self->ircd->yield('register');
    $self->ircd->add_auth( mask => '*@*' );
    $self->ircd->add_listener( port => $self->config->{port} || 6667 );

    $self->ircd->yield( add_spoofed_nick => { nick => $self->config->{server_nick} } );
}

event ircd_daemon_public => sub {
    my $self = shift;
    my($nick, $channel, $text) = get_args(@_);
    my $encoding = $self->config->{client_encoding};

    debug "public [$channel] $nick : $text";

    my $component = $self->components->{$channel};
    return unless $component;

    POE::Kernel->post( $component => send_message => decode( $encoding, $text ) );
};

event publish_message => sub {
    my $self = shift;
    my ($nick, $channel, $message) = get_args(@_);

    debug "publish to irc: [$channel] $nick : $message";

    $self->nicknames->{$channel} ||= {};
    if ($nick && !$self->nicknames->{$channel}->{$nick}) {
        $self->nicknames->{$channel}->{$nick}++;
        $self->ircd->yield( add_spoofed_nick => { nick => $nick } );
        $self->ircd->yield( daemon_cmd_join => $nick, $channel );
    }

    #$message = encode( $self->config->{client_encoding}, $message );

    $self->ircd->yield( daemon_cmd_privmsg => $nick => $channel, $_ )
        for split /\r?\n/, $message;
};

event publish_notice => sub {
    my $self = shift;
    my ($channel, $message) = get_args(@_);

    debug "notice to irc: [$channel] $message";

    #$message = encode( $self->config->{client_encoding}, $message );

    $self->ircd->yield( daemon_cmd_notice => $self->config->{server_nick} => $channel, $_ )
        for split /\r?\n/, $message;
};

event join_channel => sub {
    my $self = shift;
    my ($channel, $component) = get_args(@_);

    debug "join channel: $channel";
    debug "register: $channel => $component";

    $self->components->{$channel} = $component;
    $self->ircd->yield( daemon_cmd_join => $self->config->{server_nick}, $channel );
};

1;