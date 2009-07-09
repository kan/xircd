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

event 'start' => sub {
    my $self = shift;

    async {
        set_context $self;

        while (1) {
            debug 'time-loop';
            publish_message context->nick => time();
            Coro::AnyEvent::sleep(context->interval);
        }
    };
};

1;
__END__

=head1 NAME

XIRCD::Component::Time - sample component for xircd

=head1 AUTHORS

kan fushihara

tokuhiro matsuno

