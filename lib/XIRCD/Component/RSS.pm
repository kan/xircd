package XIRCD::Component::RSS;
use XIRCD::Component;
use Coro;
use Coro::LWP;
use Coro::AnyEvent;
use AnyEvent::HTTP;
use Encode;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Date ();
use URI;
use XML::Feed;
use XML::Feed::Deduper;
use File::Temp ();

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

sub init {
    my $self = shift;
    debug "read rss";

    my $ua = LWP::UserAgent->new(
        default_headers => HTTP::Headers->new(
            'Accept-Encoding' => 'gzip',
        ),
        follow_redirects => $self->follow_redirects,
    );

    timer(
        interval => $self->sleep,
        cb       => sub {
            debug "send request to @{[ $self->url ]}";
            my $res = $ua->get( $self->url );
            if ( $res->is_success ) {
                eval {
                    my $src = $res->decoded_content;
                    my $feed = XML::Feed->parse( \$src ) or die XML::Feed->errstr;
                    for my $entry ( $self->deduper->dedup( $feed->entries ) ) {
                        my $msg = $self->tmpl;
                        $msg =~ s/\$(\w+)/$entry->$1/eg;
                        my $nick = $entry->author || $feed->author || 'anonymous';
                        $self->publish_message($nick => $msg);
                    }
                };
                if ( my $e = $@ ) {
                    $self->publish_message('rss' => 'parse error : ' . $e);
                }
            }
            else {
                $self->publish_message('rss' => 'got a error : ' . $res->status_line);
            }
        }
    );
}

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
