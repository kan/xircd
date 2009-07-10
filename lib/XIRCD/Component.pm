package XIRCD::Component;
use Any::Moose;
use Devel::Caller::Perl qw(called_args);
use base 'Exporter';
use Coro::Specific;

our @EXPORT = qw(debug get_args yield post publish_message publish_notice timer);

sub import {
    strict->import;
    warnings->import;

    my $class = shift;
    my $mode = shift;
    my $pkg = caller(0);
    unless ($mode && $mode eq '-nocomponent') {
        any_moose()->import({into_level => 1});
        XIRCD::Base->_setup(scalar caller(0));
        XIRCD::Base->export_to_level(1);
        any_moose('Util')->can('apply_all_roles')->(
            scalar caller(0), 'XIRCD::Role'
        );
    }
    $class->export_to_level(1);
}

sub debug (@) { ## no critic.
    print @_, "\n" if $ENV{XIRCD_DEBUG};
}

sub get_args { return (called_args(0))[10..20]; }

sub yield (@) { ## no critic.
    POE::Kernel->yield(@_);
}

sub post (@) { ## no critic.
    POE::Kernel->post(@_);
}

sub publish_message {  ## no critic.
    my ($_self, $nick, $text) = @_;

    post ircd => '_publish_message' => $nick, $_self->channel, $text;
}

{
    my @timers;
    sub timer {
        my %args = @_;
        debug "new timer: $args{interval}";
        push @timers, AnyEvent->timer(
            after => 1,
            interval => $args{interval},
            cb => sub {
                debug "called timer";
                my $coro = Coro->new($args{cb});
                $coro->ready;
            },
        );
    }
}

#ub publish_notice ($) {  ## no critic.
#   my $_self = context;
#   my ($text,) = @_;

#   post ircd => '_publish_notice' => $_self->channel, $text;
#

1;
