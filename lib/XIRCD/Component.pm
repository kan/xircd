package XIRCD::Component;
use Moose;

use self;
use Devel::Caller qw(caller_args);

use Sub::Exporter -setup => {
    exports => [qw(self debug get_args http_alias)],
    groups  => { 
        default => [ -all ], 
    }
};

sub debug (@) {
    print @_, "\n\n" if $ENV{XIRCD_DEBUG};
}

sub get_args {
    return (caller_args(1))[10..20];
}

sub http_alias {
    return 'twitter_' . self->get_session_id;
}


1;
