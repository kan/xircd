package XIRCD::Component::Twitter;
use XIRCD::Component;
use Coro;
use Coro::AnyEvent;
use Coro::LWP;
use AnyEvent;

use Encode;
use HTTP::Request::Common;
use HTTP::Date ();
use JSON;
use URI;

with 'XIRCD::Role::Dedup';

has 'apiurl'   => ( isa => 'Str', is => 'rw', default => sub { 'http://twitter.com/statuses' } );
has 'apihost'  => ( isa => 'Str', is => 'rw', default => sub { 'twitter.com:80' } );
has 'apirealm' => ( isa => 'Str', is => 'rw', default => sub { 'Twitter API' } );

has 'username'   => ( isa => 'Str', is => 'rw' );
has 'password'   => ( isa => 'Str', is => 'rw' );
has 'retry'      => ( isa => 'Int', is => 'rw', default => sub { 60 } );

has ua => (
    is => 'rw',
    isa => 'LWP::UserAgent',
    default => sub {
        LWP::UserAgent->new;
    }
);

# call update.json
event send_message => sub {
    my $self = $_[0];
    my ($status,) = get_args;

    debug "send message $status";

    async {
        set_context $self;

        my $req = HTTP::Request::Common::POST(
            context->apiurl . '/update.json',
            [ status => encode('utf-8',$status) ],
        );  
        $req->authorization_basic(context->username, context->password);
        my $res = context->ua->request($req);
        if ($res->is_success) {
            my $ret = decode_json($res->content);
            publish_message 'twitter', "updated: $ret->{text}";
        } else {
            publish_message 'twitter', 'cannot update';
        }
    };
};

event start => sub {
    my $self = $_[0];
    debug "read twitter";

    async {
        set_context $self;

        while (1) {
            my $req = HTTP::Request->new(GET => context->apiurl . '/friends_timeline.json');
            $req->authorization_basic(context->username, context->password);
            my $res = context->ua->request($req);

            if ( $res->is_success ) {
                my $ret;
                eval {
                    $ret = decode_json($res->content);
                };
                if ($ret && ref $ret eq 'ARRAY') {
                    for my $line ( reverse @{ $ret || [] } ) {
                        warn "ID IS @{[ $line->{id} ]}";
                        next if context->deduper->{$line->{id}}++;
                        publish_message  $line->{user}->{screen_name} => $line->{text};
                    }
                }
            } else {
                debug "cannot get a content from twitter";
            }

            Coro::AnyEvent::sleep(context->retry);
        }
    };
};

1;

