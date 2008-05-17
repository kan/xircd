package XIRCD::Role;
use MooseX::POE::Role;
use XIRCD::Component;

use Devel::Caller qw(caller_args);

with qw(MooseX::POE::Aliased);

has name => (
    isa => 'Str',
    is  => 'rw',
);

has channel => (
    isa => 'Str',
    is  => 'rw',
);

sub START {
    my $self = shift;
    $self->alias($self->name);
    debug "start " . $self->name;

    post ircd => 'join_channel', $self->channel, $self->alias;
    yield 'start';
}



1;
