package XIRCD::Component::Rejaw;
use MooseX::POE;
use XIRCD::Component;

with qw(XIRCD::Role);

use POE qw( Component::Client::HTTP );
use HTTP::Request::Common;
use JSON::Any;
use URI;
use Encode;

has 'apikey' => ( isa => 'Str', is => 'ro', default => sub { 'tLtX0aBKOAP' } );
has 'apibase' => ( isa => 'Str', is => 'ro', default => sub { 'api.rejaw.com/v1/' } );

has 'session'  => ( isa => 'Str', is => 'rw' );
has 'email'    => ( isa => 'Str', is => 'rw' );
has 'password' => ( isa => 'Str', is => 'rw' );
has 'username' => ( isa => 'Str', is => 'rw' );
has 'counter'  => ( isa => 'Int', is => 'rw' );
has 'cid'  => ( isa => 'Str', is => 'rw' );

around 'new' => sub {
    my $call = shift;

    my $self = $call->(@_);

    POE::Component::Client::HTTP->spawn(
        Agent => 'xircd_component_rejaw/0.1',
        Alias => $self->http_alias,
    );

    return $self;
};

event start => sub {
    my $create_session =
      self->make_request( 'GET', 'session/create', { api_key => self->apikey } );
    debug 'start: ' . $create_session->as_string;
    post self->http_alias, 'request', 'got_session_create_response', $create_session;
};

event send_message => sub {
    my ($message) = get_args;

    $message = Encode::encode('utf-8', $message);

    debug "send_message $message";

    if ($message eq 'op') {
        post ircd => _daemon_server_mode => '#rejaw', '+o', '_sekimura';
        return;
    }
    elsif (my ($cid) = ($message =~ /^get_info\s+(.+)$/) ) {
        debug "get_info $cid";
        yield conversation_get_info => $cid;
        self->cid($cid);
        return;
    }
    elsif (my ($action) = ($message =~ /^\x{1}ACTION\s+(.+)\x{1}$/)) {
        debug "ACTION $action";
        yield conversation_shout => $action;
        return;
    }

    return unless self->cid;

    my $reply = self->make_request(
        'GET',
        'conversation/reply',
        {
            session => self->session,
            text    => $message,
            cid     => self->cid,
            #local_id => $local_id,
        }
    );
    debug 'conversation_reply: ' . $reply->as_string;
    post self->http_alias, 'request', 'got_conversation_reply_response', $reply;
};

event conversation_shout => sub {
    my ($text) = get_args;

    my $observe = self->make_request(
        'GET',
        'conversation/shout',
        {
            session => self->session,
            text => $text,
        }
    );
    post self->http_alias, 'request', 'got_conversation_shout', $observe;
};

event got_conversation_shout_response => sub {
    my ( $request_packet, $response_packet ) = get_args;

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    if ( $response->is_success ) {
        debug 'got coversation_shout : ' . $response->as_string;
        my $ret = JSON::Any->jsonToObj( $response->content );
        unless ( lc( $ret->{status} ) eq 'ok' ) {
            _error('failed to get session', $ret);
        }
        else {
            debug "counter " . self->counter;
            yield event_observe => "";
        }
    }
};

event got_conversation_reply_response => sub {
    my ( $request_packet, $response_packet ) = get_args;

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    if ( $response->is_success ) {
        debug 'got coversation_reply : ' . $response->as_string;
        my $ret = JSON::Any->jsonToObj( $response->content );
        unless ( lc( $ret->{status} ) eq 'ok' ) {
            _error('failed to get session', $ret);
        }
        else {
            warn "XXX counter " . self->counter;
            yield event_observe => "";
        }
    }
};

event got_session_create_response => sub {
    my ( $request_packet, $response_packet ) = get_args;

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    if ( $response->is_success ) {
        debug 'got session_create : ' . $response->as_string;
        my $ret = JSON::Any->jsonToObj( $response->content );
        unless ( lc( $ret->{status} ) eq 'ok' ) {
            _error('failed to get session', $ret);
        }
        else {
            self->session( $ret->{session} );
            debug "session: " . self->session;
            my $signin = self->make_request(
                'GET',
                'auth/signin',
                {
                    session  => self->session,
                    email    => self->email,
                    password => self->password,
                }
            );
            debug 'auth/signin: ' . $signin->as_string;
            post self->http_alias, 'request', 'got_auth_signin_response', $signin;
        }
    }
};

event got_auth_signin_response => sub {
    my ( $request_packet, $response_packet ) = get_args;

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    if ( $response->is_success ) {
        debug 'got auth_signin : ' . $response->as_string;
        my $ret = JSON::Any->jsonToObj( $response->content );
        unless ( lc( $ret->{status} ) eq 'ok' ) {
            _error('failed to subscribe', $ret);
        } else {
            self->username( $ret->{username} );
            yield subscription_subscribe => "";
        }
    }
};

event got_subscription_subscribe_response => sub {
    my ( $request_packet, $response_packet ) = get_args;

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    if ( $response->is_success ) {
        debug 'got subscription_subscribe : ' . $response->as_string;
        my $ret = JSON::Any->jsonToObj( $response->content );
        if ($ret->{status} eq 'ok') {
            self->counter( $ret->{counter} );
            yield event_observe => '';
        }
    }
};

event subscription_subscribe => sub {
    my $subscribe = self->make_request(
        'GET',
        'subscription/subscribe',
        {
            session => self->session,
            topic   => join( ', ',
                map { '/user/' . self->username . '/' . $_ }
                qw(conversations conversation_messages) ),
        }
    );
    debug 'subscription/subscribe: ' . $subscribe->as_string;
    post self->http_alias, 'request', 'got_subscription_subscribe_response', $subscribe;
};

event event_observe => sub {
    my $observe = self->make_request(
        'GET',
        'event/observe',
        {
            session => self->session,
            counter => self->counter,
        }
    );
    debug 'event_observe: ' . $observe->as_string;
    post self->http_alias, 'request', 'got_event_observe_response', $observe;
};

event got_event_observe_response => sub {
    my ( $request_packet, $response_packet ) = get_args;

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    if ( $response->is_success ) {
        debug 'got event_observe : ' . $response->as_string;
        unless ($response->content) {
            debug 'got null response: ' . $response->as_string;
        } else {
            yield handle_event_observe_response => $response;
        }
        yield event_observe => '';
    }
};

event handle_event_observe_response => sub {
    my ( $response ) = get_args;

    my $ret = JSON::Any->new->jsonToObj( $response->content );

    if ($ret->{error}) {
        debug 'got error response: ' . $response->as_string;
        yield event_observe => "";
        return;
    }

    for my $e ( @{ $ret->{events} } ) {
        ## yikes. message is wrapped as "joined" hash when it got shouts.
        my $msg = $e->{joined} ? $e->{joined} : $e;

        next if $msg->{close}; ## ignore "closed" message for now
        if ( $msg->{serial_number} > self->counter ) {
            if ( self->cid && $msg->{cid} eq self->cid ) {
                publish_message $msg->{username}, $msg->{text}
                    unless $msg->{username} eq self->username;
            }
            else {
                publish_notice sprintf "%s [%s] %s: %s", uc($msg->{type}), $msg->{cid}, 
                    $msg->{username}, $msg->{text};
            }

        }
    }

    self->counter( $ret->{counter} ) if defined $ret->{counter};
};

event conversation_get_info => sub {
    my($cid) = get_args;
    my $get_info = self->make_request(
        'GET',
        'conversation/get_info',
        {
            session => self->session,
            cid => $cid,
            include_replies => 0,
        }
    );
    debug 'conversation get_info: ' . $get_info->as_string;
    post self->http_alias, 'request', 'got_conversation_get_info', $get_info;
};

event got_conversation_get_info => sub {
    my ( $request_packet, $response_packet ) = get_args;

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    if ( $response->is_success ) {
        debug 'got conversation get_info : ' . $response->as_string;
        my $ret = JSON::Any->new->jsonToObj( $response->content );
        if ($ret->{status} eq 'ok') {
            for my $msg (@{ $ret->{conversations} }) {
                publish_notice sprintf "%s [%s] %s: %s", uc($msg->{type}), $msg->{cid}, 
                        $msg->{username},
                        $msg->{text};
                for my $m (@{ $msg->{messages} } ) {
                    publish_notice sprintf "%s [%s] %s: %s", uc($m->{type}), $m->{cid}, 
                        $m->{username},
                        $m->{text};
                }
            }
        }
    }
};

sub make_request {
    my ($self, $method, $path, $params ) = @_;

    ## http://code.google.com/p/rejaw/wiki/RejawEventArchitecture
    #
    # Keep-Alive issue
    #    Some HTTP client implementations are known to try establishing 
    #    keep-alive connection to the web server, which means that the 
    #    event.observe calls might try to reuse the connection established
    #    for previous requests such as session.create or 
    #    subscription.subscribe. This will fail, because the machines in
    #    web server clusters do not serve event.observe calls.
    #
    #    To avoid this problem, it is RECOMMENDED to use a different host
    #    names between event.observe and other methods. 

    my $salt = int rand (1_000_000);
    my $uribase =
      $path eq 'event/observe' ? $salt . '.' . $self->apibase : $self->apibase;

    my $uri = URI->new( 'http://' . $uribase . $path . '.json' );
    $uri->query_form(%$params);
    my $req = HTTP::Request->new( $method, $uri->as_string );
    return $req;
}

sub _error {
    my ($msg, $ret) = @_;
    debug sprintf ("%s: [%s] %s", $msg, $ret->{error}{code}, $ret->{error}{message});
}

1;
