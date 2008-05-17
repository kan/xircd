package XIRCD::Component::Server;
use strict;
use MooseX::POE;

with qw(MooseX::POE::Aliased);

use Clone qw/clone/;
use Encode;

use XIRCD::Component;
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
    self->alias('ircd');

    debug "start irc";

    self->config->{servername} ||= 'xircd.ircd';
    self->config->{client_encoding} ||= 'utf-8';

    self->ircd(POE::Component::Server::IRC->spawn( config => clone(self->config) ));
    self->ircd->yield('register');
    self->ircd->add_auth( mask => '*@*' );
    self->ircd->add_listener( port => self->config->{port} || 6667 );

    self->ircd->yield( add_spoofed_nick => { nick => self->config->{server_nick} } );
}

event ircd_daemon_join => sub {
    my($user, $channel) = get_args;

    return unless my($nick) = $user =~ /^([^!]+)!/;
    return if self->nicknames->{$channel}->{$nick};
    return if $nick eq self->config->{server_nick};

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
    return if $nick eq self->config->{server_nick};

    for my $channel ( keys %{self->joined} ) {
        next if self->nicknames->{$channel}->{$nick};
        self->joined->{$channel} = 0;
    }
};

event ircd_daemon_part => sub {
    my($user, $channel) = get_args;

    return unless my($nick) = $user =~ /^([^!]+)!/;
    return if self->nicknames->{$channel}->{$nick};
    return if $nick eq self->config->{server_nick};

    self->joined->{$channel} = 0;
};

event ircd_daemon_public => sub {
    my($nick, $channel, $text) = get_args;
    my $encoding = self->config->{client_encoding};

    debug "public [$channel] $nick : $text";

    my $component = self->components->{$channel};
    return unless $component;
    debug "send to $component";

    post $component => send_message => decode( $encoding, $text );
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

    #$message = encode( self->config->{client_encoding}, $message );

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

    #$message = encode( self->config->{client_encoding}, $message );

    self->ircd->yield( daemon_cmd_notice => self->config->{server_nick} => $channel, $_ )
        for split /\r?\n/, $message;
};

event join_channel => sub {
    my ($channel, $component) = get_args;

    debug "join channel: $channel";
    debug "register: $channel => $component";

    self->components->{$channel} = $component;
    self->ircd->yield( daemon_cmd_join => self->config->{server_nick}, $channel );
};

1;
