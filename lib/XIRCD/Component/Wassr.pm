package XIRCD::Component::Wassr;
use XIRCD::Component;
use Coro;
use Coro::AnyEvent;
use AnyEvent;
use AnyEvent::XMPP::Client;

has 'username' => ( isa => 'Str', is => 'rw' );
has 'password' => ( isa => 'Str', is => 'rw' );
has 'server'   => ( isa => 'Str', is => 'rw' );
has 'port'     => ( isa => 'Int', is => 'rw', default => sub { 5222 } );

has jabber => (
    is => 'rw',
    isa => 'AnyEvent::XMPP::Client',
);

has 'jid' => (
    isa     => 'Str',
    is      => 'rw',
);

sub init {
    my $self = shift;
    debug "start wassr";

    my $cl = AnyEvent::XMPP::Client->new( debug => 0 );
    $cl->add_account( $self->username, $self->password, $self->server, $self->port );
    $cl->reg_cb(
        session_ready => sub {
            debug "sesssion_ready";
        },
        connected => sub {
            debug "connected";
        },
        message => sub {
            my ($cl, $acc, $msg) = @_;
            debug "got message";

            async {
                my $from = $msg->from;
                my $body = $msg->any_body;
                debug "'$body' from '$from'";
                if ($body && $from =~ /^wassr-bot\@wassr\.jp/) {
                    my ($nick, $text) = $body =~ /^([A-Za-z0-9_.-]+): (.*)/s;
                    if ($nick && $text) {
                        $self->publish_message($nick => $text);
                    } else {
                        $self->publish_message('wassr' => $body);
                    }
                }
            };
        },
    );
    $cl->start;
    $self->jabber($cl);
}

# FIXME: this routine doesn't works
sub receive_message {
    my ($self, $message) = @_;

    debug "send:", $message;
    $self->jabber->send_message('test', 'wassr-bot@wassr.jp');
}

1;
