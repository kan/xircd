package XIRCD::Component::Time;
use strict;
use MooseX::POE;
use XIRCD::Component;
with qw(XIRCD::Role);
use DateTime;

has 'nick' => (
    is  => 'rw',
    isa => 'Str',
);

event start => sub {
    my $date = DateTime->now(time_zone => 'Asia/Tokyo');
    publish_message self->nick => $date->strftime("%Y/%m/%d %H:%M:%S");
    delay 'start', 10;
};


1;

