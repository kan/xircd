package XIRCD::Component::Wassr;
use strict;
use MooseX::POE;
use XIRCD::Component;

with 'XIRCD::Role';

use POE qw(
    Component::Jabber
    Component::Jabber::Error
    Component::Jabber::Status
    Component::Jabber::ProtocolFactory
    Filter::XML::Node
    Filter::XML::Utils
);
use POE::Filter::XML::NS qw/:JABBER :IQ/;

has 'jabber' => (
    isa     => 'POE::Component::Jabber',
    is      => 'rw',
);

has 'username' => ( isa => 'Str', is => 'rw' );
has 'password' => ( isa => 'Str', is => 'rw' );
has 'server'   => ( isa => 'Str', is => 'rw' );
has 'port'     => ( isa => 'Int', is => 'rw', default => sub { 5222 } );

has 'jid' => (
    isa     => 'Str',
    is      => 'rw',
);

event start => sub {
    debug "start wassr";
    my ($username, $hostname) = split '@', self->username;

    self->jabber(
        POE::Component::Jabber->new(
            IP       => self->server,
            Port     => self->port,
            Hostname => $hostname,
            Username => $username,
            Password => self->password,
            Alias    => 'jabber',
            States   => {
                StatusEvent => 'status_handler',
                InputEvent  => 'input_handler',
                ErrorEvent  => 'error_handler',
            },
            ConnectionType => +XMPP,
        )
    );

    post jabber => 'connect';
};

event status_handler => sub {
    my ($state,) = get_args;

    if ($state == +PCJ_INIT_FINISHED) {
        debug "init finished";
        self->jid(self->jabber->jid);

        post jabber => 'output_handler', POE::Filter::XML::Node->new('presence');
        post jabber => 'purge_queue';
    }
};

event input_handler => sub {
    my ($node,) = get_args;

    debug "recv:", $node->to_str;

    my ($body,) = $node->get_tag('body');

    if ($body && $node->attr('from') =~ /^wassr-bot\@wassr\.jp/) {
        my ($nick, $text) = $body->data =~ /^([A-Za-z0-9_.-]+): (.*)/s;
        if ($nick && $text) {
            publish_message $nick => $text;
        } else {
            publish_notice $body->data;
        }
    }
};

event send_message => sub {
    my ($message,) = get_args;

    my $node = POE::Filter::XML::Node->new('message');

    $node->attr('to', 'wassr-bot@wassr.jp');
    $node->attr('from', self->{jid} );
    $node->attr('type', 'chat');
    $node->insert_tag('body')->data( $message );

    debug "send:", $node->to_str;

    post jabber => output_handler => $node;
};

event error_handler => sub {
    my ($error,) = get_args;

    if ( $error == +PCJ_SOCKETFAIL or $error == +PCJ_SOCKETDISCONNECT or $error == +PCJ_CONNECTFAIL ) {
        debug "Reconnecting!";
        post jabber => 'reconnect';
    }
    elsif ( $error == +PCJ_SSLFAIL ) {
        debug "TLS/SSL negotiation failed";
    }
    elsif ( $error == +PCJ_AUTHFAIL ) {
        debug "Failed to authenticate";
    }
    elsif ( $error == +PCJ_BINDFAIL ) {
        debug "Failed to bind a resource";
    }
    elsif ( $error == +PCJ_SESSIONFAIL ) {
        debug "Failed to establish a session";
    }
};


1;
