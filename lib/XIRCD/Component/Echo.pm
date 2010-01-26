package XIRCD::Component::Echo;
use XIRCD::Component;
use Coro;
use Coro::AnyEvent;
use AnyEvent;

has 'nick' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'echo-bot',
);

sub receive_message {
    my ($self, $msg) = @_;
    debug "[Echo] received: $msg";
    unless ($msg =~ /^I got '/) {
        $self->publish_message($self->nick => "I got '$msg'");
    }
}

1;
__END__

=head1 NAME

XIRCD::Component::Echo - sample component for xircd

=head1 AUTHORS

tokuhiro matsuno

