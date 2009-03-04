package XIRCD::Component;
use Moose;
use self;
use Devel::Caller qw(caller_args);
use Exporter 'import';

our @EXPORT = qw(self debug get_args http_alias yield delay post publish_message publish_notice);

sub debug (@) { ## no critic.
    print @_, "\n" if $ENV{XIRCD_DEBUG};
}

sub get_args { return (caller_args(1))[10..20]; }

sub http_alias {
    return 'twitter_' . self->get_session_id;
}

sub yield (@) { ## no critic.
    POE::Kernel->yield(@_);
}

sub delay (@) { ## no critic.
    POE::Kernel->delay(@_);
}

sub post (@) { ## no critic.
    POE::Kernel->post(@_);
}

sub publish_message ($$) {  ## no critic.
    my $_self = (caller_args(1))[0];
    my ($nick, $text) = @_;

    post ircd => '_publish_message' => $nick, $_self->channel, $text;
}

sub publish_notice ($) {  ## no critic.
    my $_self = (caller_args(1))[0];
    my ($text,) = @_;

    post ircd => '_publish_notice' => $_self->channel, $text;
}

1;
