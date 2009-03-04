package XIRCD::Role;
use Moose::Role;
use XIRCD::Component;
with 'MooseX::POE::Aliased';

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

    post ircd => 'join_channel', $self->channel, $self->get_session_id;
    yield 'start';
}

1;
