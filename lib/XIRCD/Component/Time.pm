package XIRCD::Component::Time;
use MooseX::POE;

with qw(MooseX::POE::Aliased);

use DateTime;

has 'config' => (
    isa => 'HashRef',
    is  => 'rw',
);

has 'date' => (
    isa     => 'DateTime',
    is      => 'ro',
    default => sub { DateTime->now( time_zone => 'Asia/Tokyo' ) },
);

sub debug(@) { ## no critic.
    print @_ if $ENV{XIRCD_DEBUG};
}

sub START {
    my $self = shift;

    $self->alias('time');

    debug 'start time';

    POE::Kernel->post( ircd => 'join_channel', $self->config->{channel} );
    $self->yield('timecall');
}

event timecall => sub {
    my $self = shift;

    debug "timecall";

    POE::Kernel->post( ircd => 'publish_message' => 'time', $self->config->{channel}, $self->date->strftime("%Y/%m/%d %H:%M:%S") );
    POE::Kernel->delay('timecall', 10);
};


1;
