package XIRCD::Role;
use Any::Moose '::Role';
use XIRCD::Component '-nocomponent';

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

    post ircd => 'join_channel', $self->channel, $self->poe_session_id;

    $self->init_component();

    yield 'start';
}

sub init_component {
    # nop
}

1;
