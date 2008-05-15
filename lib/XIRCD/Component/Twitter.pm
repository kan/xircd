package XIRCD::Component::Twitter;
use MooseX::POE;

with qw(MooseX::POE::Aliased);

use HTTP::Request::Common;
use HTTP::Date ();
use JSON::Any;
use POE qw( Component::Client::HTTP );
use URI;


has 'config' => (
    isa => 'HashRef',
    is  => 'rw',
);

has 'since' => (
    is => 'rw',
);

sub debug(@) { ## no critic.
    print @_,"\n\n" if $ENV{XIRCD_DEBUG};
}

sub get_args(@) { ## no critic.
    return @_[9..19];
}

sub http_alias {
    my $self = shift;
    return 'twitter_' . $self->get_session_id;
}

around 'new' => sub {
    my $call = shift;

    my $self = $call->(@_);

    POE::Component::Client::HTTP->spawn(
        Agent => 'xircd_component_twitter/0.1',
        Alias => $self->http_alias,
    );

    $self->config->{apiurl}   ||= 'http://twitter.com/statuses';
    $self->config->{apihost}  ||= 'twitter.com:80';
    $self->config->{apirealm} ||= 'Twitter API';
    $self->config->{alias}    ||= 'twitter';

    return $self;
};

sub START {
    my $self = shift;

    $self->alias('twitter');

    debug "start twitter";

    POE::Kernel->post( ircd => 'join_channel', $self->config->{channel}, $self->alias );
    $self->yield('read_twitter_friend_timeline');
}

event read_twitter_friend_timeline => sub {
    my $self = shift;

    debug "read twitter";

    my $uri = URI->new($self->config->{apiurl} . '/friends_timeline.json');
    $uri->query_form(since => HTTP::Date::time2str($self->since)) if $self->since;
    $self->since(time);

    my $req = HTTP::Request->new(GET => $uri);
    $req->authorization_basic($self->config->{twitter}->{username}, $self->config->{twitter}->{password});

    POE::Kernel->post($self->http_alias => request => 'http_response', $req);
};

event http_response => sub {
    my $self = shift;
    my ($request_packet, $response_packet) = get_args(@_);

    my $request  = $request_packet->[0];
    my $response = $response_packet->[0];

    my $uri = $request->uri;
    if ($uri =~ /update.json/) {
        unless ($response->is_success) {
            $self->yield(response_error => $response);
            return;
        }
        $self->yield(update_success => $response);
    } elsif ($uri =~ /friends_timeline.json/) {
        $self->yield(friend_timeline_success => $response);
    }
};

event friend_timeline_success => sub {
    my $self = shift;

    debug "get friend timeline";
    my ( $response, ) = get_args(@_);

    if ( $response->is_success ) {
        my $ret = JSON::Any->jsonToObj($response->content);
        for my $line ( reverse @{ $ret || [] } ) {
            POE::Kernel->post(
                ircd => publish_message => 
                    $line->{user}->{screen_name},
                    $self->config->{channel}, 
                    $line->{text},
            );
        }
    }

    POE::Kernel->delay('read_twitter_friend_timeline', $self->config->{twitter}->{retry});
};


1;

