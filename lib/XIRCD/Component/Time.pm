package XIRCD::Component::Time;
use XIRCD::Component;
use Coro;
use Coro::AnyEvent;
use AnyEvent;

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

sub init {
    my $self = shift;

    timer(
        interval => $self->interval,
        cb => sub{
            debug 'time-loop';
            $self->publish_message($self->nick => time());
        }
    );
}

1;
__END__

=head1 NAME

XIRCD::Component::Time - sample component for xircd

=head1 AUTHORS

kan fushihara

tokuhiro matsuno

