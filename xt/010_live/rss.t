use strict;
use warnings;
use AnyEvent::Impl::POE;
use AnyEvent;
use Coro;
use Test::TCP;
use XIRCD::Server;
use XIRCD::Component::RSS;
use AnyEvent::IRC;
use AnyEvent::IRC::Connection;
use AnyEvent::IRC::Client;
use Test::More tests => 3;
use YAML;

test_tcp(
    client => sub {
        my $port = shift;
        my $c = AnyEvent->condvar;

        my $con;

        my $t;
        $t = AnyEvent->timer (after => 40, cb => sub {
            fail "timeout";
            $con->disconnect ("Timeout exceeded");
            undef $t;
        });

        diag 'start connection';
        my $tested = 0;
        $con = AnyEvent::IRC::Client->new;
        $con->reg_cb(
            'connect' => sub {
                my ( $con, $err ) = @_;
                if ( defined $err ) {
                    BAIL_OUT "Connect ERROR! => $err\n";
                    $c->broadcast;
                }
                else {
                    note "Connected! Yay!\n";
                }
                $con->send_msg ("NICK", 'test');
                $con->send_msg ("USER", 'test', "*", "0", 'test');
                $con->send_chan("PRIVMSG", "#rss", "Hi!!!");
            },
            registered => sub {
                my ($self) = @_;
                note "registered!\n";
                $con->enable_ping (60);
                $con->send_srv("JOIN", "#rss");
                $con->send_chan("#rss", "PRIVMSG", "#rss", "hi, i'm a bot!");
            },
            irc_001 => sub {
                note 'irc_001';
                print "$_[1]->{prefix} says I'm in the IRC: $_[1]->{params}->[-1]!\n";
            },
            irc_privmsg => sub {
                my ($self, $msg) = @_;
                if ($tested == 0) {
                    is $msg->{command}, 'PRIVMSG';
                    is $msg->{params}->[0], '#rss';
                    note $msg->{params}->[1];
                    ok $msg->{params}->[1];
                    $c->send($msg);
                    note Dump($msg);
                    $tested++;
                }
            },
            disconnect => sub {
                BAIL_OUT "Oh, got a disconnect: $_[1], exiting...\n";
            }
        );
        $con->connect( 'localhost', $port,
            { nick => 'bee', 'user' => 'bee', real => 'the bot' } );

        local $SIG{INT} = sub { BAIL_OUT "SIGINT" };
        $c->recv;
    },
    server => sub {
        my $port = shift;

        my $server = XIRCD::Server->new(
            port => $port,
        );

        async {
            my $component = XIRCD::Component::RSS->new(
                url => 'http://blog.livedoor.jp/dankogai/index.rdf',
            );
            $server->register($component);
        };

        local $SIG{INT} = sub { BAIL_OUT "SIGINT" };
        AnyEvent->condvar->recv; # main loop
    },
);
