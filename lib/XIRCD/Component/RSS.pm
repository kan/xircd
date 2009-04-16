package XIRCD::Component::RSS;
use XIRCD::Component;
use strict;

use Encode;
use HTTP::Request::Common;
use HTTP::Date ();
use POE qw( Component::Client::HTTP );
use URI;
use XML::Feed;
use XML::Feed::Deduper;
use File::Temp ();

has 'http_alias' => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        my $self = shift;
        "http_$self";
    },
);

has 'deduper' => (
    is      => 'rw',
    isa     => 'XML::Feed::Deduper',
    lazy    => 1,
    default => sub {
        my $self = shift;
        XML::Feed::Deduper->new( path => "$self->{deduper_path}" );
    },
);

has deduper_path => (
    is      => 'rw',
    isa     => 'File::Temp',
    default => sub {
        File::Temp->new( UNLINK => 1 );
    },
);

has tmpl => (
    is      => 'ro',
    isa     => 'Str',
    default => '$title($link)',
);

has url => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has sleep => (
    is      => 'ro',
    isa     => 'Int',
    default => 60,
);

has follow_redirects => (
    is      => 'ro',
    isa     => 'Int',
    default => 2,
);

sub init_component {
    debug "alias of client::http is " . self->http_alias;

    POE::Component::Client::HTTP->spawn(
        Agent => 'xircd_component_twitter/0.1',
        Alias => self->http_alias,
        FollowRedirects => self->follow_redirects,
    );
}

event start => sub {
    debug "read rss";

    debug "send request to @{[ self->url ]}";

    my $req = HTTP::Request->new(GET => self->url, [
        'Accept-Encoding' => 'gzip'
    ]);
    post self->http_alias() => request => 'http_response', $req;
};

event http_response => sub {
    my ($request_packet, $response_packet) = get_args;

    debug "we seen http-response";

    my $req = $request_packet->[0];
    my $res = $response_packet->[0];

    if ($res->is_success) {
        eval {
            my $src = $res->decoded_content;
            my $feed = XML::Feed->parse(\$src) or die XML::Feed->errstr;
            for my $entry (self->deduper->dedup($feed->entries)) {
                my $msg = self->tmpl;
                $msg =~ s/\$(\w+)/$entry->$1/eg;
                my $nick = $entry->author || $feed->author || 'anonymous';
                publish_message $nick => $msg;
            }
        };
        if (my $e = $@) {
            publish_message 'rss' => 'parse error : ' . $e;
        }
    } else {
        publish_message 'rss' => 'got a error : ' . $res->status_line;
    }

    delay start => self->sleep;
};

1;
__END__

=head1 NAME

XIRCD::Component::RSS - rss fetcher

=head1 SYNOPSIS

  - module: RSS
    url: http://www.hatena.ne.jp/acotie/antenna.rss
    sleep: 60
    channel: '#acotie'

=head1 DESCRIPTION

fetch the rss and post it!

=head1 AUTHOR

Tokuhiro Matsuno
