package XIRCD::Component;
use Moose;

use Sub::Exporter -setup => {
    exports => [qw(debug get_args http_alias)],
    groups  => { 
        default => [ -all ], 
    }
};

sub debug (@) {
    print @_, "\n\n" if $ENV{XIRCD_DEBUG};
}

sub get_args (@) {
    return @_[9..19];
}

sub http_alias {
    my $self = shift;
    return 'twitter_' . $self->get_session_id;
}


1;
