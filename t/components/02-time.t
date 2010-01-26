use strict;
use warnings;
use Test::Requires 'AnyEvent::IRC::Client';
use Test::TCP;
use AE;
use XIRCD;
use Test::More;

test_tcp(
    client => sub {
        my $port = shift;
        my $cv = AE::cv();

        my $irc = AnyEvent::IRC::Client->new();
        $irc->reg_cb(
            registered => sub {
                my ($irc) = @_;
                $irc->send_srv('JOIN', '#time');
            },
            'irc_privmsg' => sub {
                my ($irc, $raw) = @_;
                if ($raw->{params}->[1] =~ /^\d+$/) {
                    ok 1, 'got response';
                    $cv->send();
                }
            },
        );
        $irc->connect(
            '127.0.0.1',
            $port,
            {
                user => 'john',
                real => 'john',
                nick => 'john',
            },
        );

        $cv->recv();

        done_testing;
    },
    server => sub {
        my $port = shift;
        my $xircd = XIRCD->new(
            config => {
                'ircd' => {
                    port => $port,
                    server_nick => 'xircd',
                    servername => 'xircd.local',
                },
                components => [
                    {module => 'Time'},
                ],
            },
        );
        
        AE::cv()->recv();
    },
);


