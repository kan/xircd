package XIRCD::Component;
use Any::Moose;
use XIRCD::Util qw/debug/;
use AE;
use base 'Exporter';

our @EXPORT = qw(debug publish_message timer);

sub import {
    my $class = shift;
    my $mode = shift;
    my $caller = caller(0);

    strict->import;
    warnings->import;

    any_moose()->import({into_level => 1});
    any_moose('Util')->can('apply_all_roles')->(
        $caller, 'XIRCD::Role::Component'
    );
    $class->export_to_level(1);
}

sub publish_message {  ## no critic.
    my ($_self, $nick, $text) = @_;
    XIRCD->context->server->publish_message($nick, $_self->channel, $text);
}

{
    my @timers;
    sub timer {
        my %args = @_;
        debug "new timer: $args{interval}";
        push @timers, AE::timer(
            after => 1,
            interval => $args{interval},
            cb => sub {
                # debug "called timer";
                my $coro = Coro->new($args{cb});
                $coro->ready;
            },
        );
    }
}

1;
