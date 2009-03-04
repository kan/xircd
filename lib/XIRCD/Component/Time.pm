package XIRCD::Component::Time;
use MooseX::POE;
use XIRCD::Component;

has 'nick' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'time-bot',
);

has 'interval' => (
    is => 'ro',
    isa => 'Int',
    default => 10,
);

event start => sub {
    publish_message self->nick => time();
    delay 'start', self->interval;
};

1;
__END__

=head1 NAME

XIRCD::Component::Time - sample component for xircd

=head1 AUTHORS

kan fushihara

tokuhiro matsuno

