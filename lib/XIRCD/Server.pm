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

sub debug(@) { ## no critic.
    print @_ if $ENV{XIRCD_DEBUG};
}

sub get_args(@) { ## no critic.
    return @_[9..19];
}

sub START {
    my $self = shift;

    $self->alias('ircd');

    $self->config->{servername} ||= 'xircd.ircd';
    $self->config->{client_encoding} ||= 'utf-8';

    $self->ircd(POE::Component::Server::IRC->spawn( config => clone($self->config) ));
    $self->ircd->yield('register');
    $self->ircd->add_auth( mask => '*@*' );
    $self->ircd->add_listener( port => $self->config->{port} || 6667 );

    debug "start irc \n\n";

    $self->ircd->yield( add_spoofed_nick => { nick => $self->config->{server_nick} } );
}

event ircd_daemon_public => sub {
    my ($self, $user, $channel, $text) = @_;
    my $encoding = $self->config->{client_encoding};

    POE::Kernel->post( im => send_message => decode( $encoding, $text ) );
    POE::Kernel->post( ustream => say => decode( $encoding, $text ) );
};

event publish_message => sub {
    my $self = shift;
    my ($channel, $message) = get_args(@_);

    debug "publish to irc: [$channel] $message \n\n";

    $message = encode( $self->config->{client_encoding}, $message );

    my $say = sub {
        my ($nick, $text) = @_;
        $self->ircd->yield( daemon_cmd_privmsg => $nick => $channel, $_ )
            for split /\r?\n/, $text;
    };

    $say->($self->config->{server_nick}, $message);
};

event join_channel => sub {
    my $self = shift;
    my ($channel,) = get_args(@_);

    debug "join channel: $channel";

    $self->ircd->yield( daemon_cmd_join => $self->config->{server_nick}, $channel );
};

1;
