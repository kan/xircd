package XIRCD::Server;
use Any::Moose;
use XIRCD::Util qw/debug/;
use AnyEvent::IRC::Server;
use AnyEvent::IRC::Util qw/prefix_nick/;

use Encode ();

{
    my %SERVER_EVENTS;

    sub _build_ircd {
        my $self = shift;
        debug "BUILDING SERVER";

        my $ircd = AnyEvent::IRC::Server->new(
            servername => $self->servername,
            port       => $self->port,
            %{ $self->ircd_option },
        );
        $ircd->reg_cb(do {
            my %cb;
            while ( my ($name, $code) = each %SERVER_EVENTS ) {
                $cb{$name} = sub { $code->($self, @_) };
            }
            %cb;
        });

#       for my $auth (@{ $self->auth }) {
#           $ircd->add_auth( %{$auth} );
#       }
#       $ircd->add_spoofed_nick($self->server_nick);

        $ircd->run();

        debug "start server at localhost:" . $self->port . ' server nick is ' . $self->server_nick;

        return $ircd;
    }

    sub event ($&) { ## no critic
        # my $pkg = caller(0);
        my ( $event_name, $cb ) = @_;

        # my $method_name = "__event_$event_name";
        # $pkg->meta->add_method( $method_name => $cb );
        $SERVER_EVENTS{$event_name} = $cb;
    }
}

has 'ircd' => (
    isa => 'AnyEvent::IRC::Server',
    is  => 'rw',
    lazy => 1,
    builder => '_build_ircd',
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
    default => sub { +[ {mask => '*@*'} ] },
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

# Is any user joined to the channel?
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

event daemon_join => sub {
    my ($self, $ircd, $nick, $channel) = @_;
    $nick = prefix_nick($nick);
    debug "-- daemon_join: $nick, $channel";

    return if $self->nicknames->{$channel}->{$nick};
    return if $nick eq $self->server_nick;

    $self->joined->{$channel} = 1;

    for my $message ( @{ $self->message_stack->{$channel} || [] } ) {
        my $text = Encode::encode( $self->client_encoding, $message->{text} );
        $self->ircd->daemon_cmd_privmsg(
            $message->{nick},
            $channel,
            $text,
        );
    }
    $self->message_stack->{$channel} = [];
};

# TODO: implement in AnyEvent::IRC::Server
event daemon_quit => sub {
    my ($self, $ircd, $nick) = @_;
    $nick = prefix_nick($nick);

    return if $nick eq $self->server_nick;

    for my $channel ( keys %{$self->joined} ) {
        next if $self->nicknames->{$channel}->{$nick};
        $self->joined->{$channel} = 0;
    }
};

# TODO: implement in AnyEvent::IRC::Server
event daemon_part => sub {
    my ($self, $ircd, $nick, $channel) = @_;
    $nick = prefix_nick($nick);

    return if $self->nicknames->{$channel}->{$nick};
    return if $nick eq $self->server_nick;

    $self->joined->{$channel} = 0;
};

event daemon_privmsg => sub {
    my ($self, $ircd, $nick, $channel, $text) = @_;

    debug "public [$channel] $nick : $text";

    my $component = $self->components->{$channel};
    return unless $component;
    debug "send to $component";

    if ($component->can('receive_message')) {
        $component->receive_message(Encode::decode($self->client_encoding, $text));
    }
};

sub publish_message {
    my ($self, $nick, $channel, $message) = @_;

    debug "publish to irc: [$channel] $nick : $message";

    $self->nicknames->{$channel} ||= {};
    if ($nick && !$self->nicknames->{$channel}->{$nick}) {
        $self->nicknames->{$channel}->{$nick}++;
#       $self->ircd->yield( add_spoofed_nick => { nick => $nick } );
        $self->ircd->daemon_cmd_join( $nick, $channel );
    }

    if ( $self->joined->{$channel} ) {
        $message = Encode::encode( $self->client_encoding, $message );
        $self->ircd->daemon_cmd_privmsg( $nick => $channel, $_ )
            for split /\r?\n/, $message;
    } else {
        debug "not joined channel: $channel";
        $self->message_stack->{$channel} ||= [];
        push @{$self->message_stack->{$channel}}, { nick => $nick, text => $message };
    }
}

# register the component to ircd
sub register {
    my ($self, $component) = @_;
    my $channel = $component->channel;

    debug "join channel: $channel";
    debug "register: $channel => $component";

    $self->components->{$channel} = $component;
    $self->ircd->daemon_cmd_join( $self->server_nick, $channel );
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
