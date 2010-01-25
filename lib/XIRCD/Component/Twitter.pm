package XIRCD::Component::Twitter;
use XIRCD::Component;
use Coro;
use Coro::AnyEvent;
use Coro::LWP;
use AnyEvent;
use LWP::UserAgent;

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
sub receive_message {
    my ($self, $status) = @_;

    debug "send message $status";

    async {
        my $req = HTTP::Request::Common::POST(
            $self->apiurl . '/update.json',
            [ status => encode('utf-8',$status) ],
        );  
        $req->authorization_basic($self->username, $self->password);
        my $res = $self->ua->request($req);
        if ($res->is_success) {
            my $ret = decode_json($res->content);
            $self->publish_message('twitter', "updated: $ret->{text}");
        } else {
            $self->publish_message('twitter', 'cannot update');
        }
    };
}

sub init {
    my $self = shift;
    debug "read twitter";

    timer(
        interval => $self->retry,
        cb => sub {
            my $req = HTTP::Request->new(GET => $self->apiurl . '/friends_timeline.json');
            $req->authorization_basic($self->username, $self->password);
            my $res = $self->ua->request($req);

            if ( $res->is_success ) {
                my $ret;
                eval {
                    $ret = decode_json($res->content);
                };
                if ($ret && ref $ret eq 'ARRAY') {
                    for my $line ( reverse @{ $ret || [] } ) {
                        warn "ID IS @{[ $line->{id} ]}";
                        next if $self->deduper->{$line->{id}}++;
                        $self->publish_message($line->{user}->{screen_name} => $line->{text});
                    }
                }
            } else {
                debug "cannot get a content from twitter";
            }
        },
    );
}

1;

