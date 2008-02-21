package XIRCD::Server;
use strict;
use warnings;

use Clone qw/clone/;
use Encode;

use POE qw/Component::Server::IRC/;

sub spawn {
    my $class = shift;
    my $config = @_ > 1 ? {@_} : $_[0];

    $config->{servername} ||= 'xircd.ircd';
    $config->{client_encoding} ||= 'utf-8';

    my $ircd = POE::Component::Server::IRC->spawn( config => clone($config) );
    POE::Session->create(
        package_states => [
            __PACKAGE__, [qw/_start ircd_daemon_public publish_message join_channel/],
        ],
        heap => { ircd => $ircd, config => $config },
    );
}

sub debug(@) { ## no critic.
    print @_ if $ENV{XIRCD_DEBUG};
}

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    $kernel->alias_set('ircd');

    my ($ircd, $config) = @$heap{qw/ircd config/};

    $ircd->yield('register');
    $ircd->add_auth( mask => '*@*' );
    $ircd->add_listener( port => $config->{port} || 6667 );

    debug "start irc \n\n";

    $ircd->yield( add_spoofed_nick => { nick => $config->{server_nick} } );

    $heap->{nicknames} = {};
}

sub ircd_daemon_public {
    my ($kernel, $heap, $user, $channel, $text) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    my $encoding = $heap->{config}{client_encoding};

    $kernel->post( im => send_message => decode( $encoding, $text ) );
    $kernel->post( ustream => say => decode( $encoding, $text ) );
}

sub publish_message {
    my ($kernel, $heap, $channel, $message) = @_[KERNEL, HEAP, ARG0, ARG1];

    debug "publish to irc: [$channel] $message \n\n";

    my ($ircd, $config) = @$heap{qw/ircd config/};
    $message = encode( $config->{client_encoding}, $message );

    my $say = sub {
        my ($nick, $text) = @_;
        $ircd->yield( daemon_cmd_privmsg => $nick => $channel, $_ )
            for split /\r?\n/, $text;
    };

    $say->($config->{server_nick}, $message);
}

sub join_channel {
    my ($kernel, $heap, $channel) = @_[KERNEL, HEAP, ARG0];
    my ($ircd, $config) = @$heap{qw/ircd config/};

    debug "join channel: $channel";

    $ircd->yield( daemon_cmd_join => $config->{server_nick}, $channel );
}

1;
