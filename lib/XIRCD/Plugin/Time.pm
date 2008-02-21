package XIRCD::Plugin::Time;
use strict;
use warnings;

use POE;
use DateTime;

sub spawn {
    my ($class, $config) = @_;

    use Data::Dumper;
    warn Dumper $config;
    POE::Session->create(
        package_states => [
            __PACKAGE__, [qw/_start timecall/],
        ],
        heap => { config => $config },
    );
}

sub debug(@) { ## no critic.
    print @_ if $ENV{XIRCD_DEBUG};
}

sub _start {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    $kernel->alias_set('time');

    debug 'start time';
    use Data::Dumper;
    warn Dumper $heap->{config};

    $kernel->post( ircd => 'join_channel', $heap->{config}->{channel} );
    $kernel->yield('timecall');
}

sub timecall {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    debug "timecall";

    my $date = DateTime->now(time_zone => 'Asia/Tokyo');
    $kernel->post( ircd => 'publish_message', $heap->{config}->{channel}, $date->strftime("%Y/%m/%d %H:%M:%S") );

    sleep(10);
    $kernel->yield('timecall');
}


1;
