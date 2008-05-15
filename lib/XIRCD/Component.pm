package XIRCD::Component;
use Moose;

use Sub::Exporter;
use Sub::Name qw/subname/;

my %exports = (
    debug => sub {
        return subname 'XIRCD::Component::debug' => sub (@) {
            print @_, "\n\n" if $ENV{XIRCD_DEBUG};
        };
    },
    get_args => sub {
        return subname 'XIRCD::Component::get_args' => sub (@) {
            return @_[9..19];
        };
    },
    http_alias => sub {
        return subname 'XIRCD::Component::http_alias' => sub {
            my $self = shift;
            return 'twitter_' . $self->get_session_id;
        };
    },
);

my $exporter = Sub::Exporter::build_exporter(
    {
        exports => \%exports,
        groups  => { default => [':all'] }
    }
);

sub import {
    my ( $pkg, $subclass ) = @_;

    return if caller() eq 'main';

    goto $exporter;
}


1;
