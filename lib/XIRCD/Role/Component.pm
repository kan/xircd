package XIRCD::Role::Component;
use Any::Moose '::Role';
use XIRCD::Util qw/debug/;

has name => (
    isa => 'Str',
    is  => 'rw',
);

has channel => (
    isa => 'Str',
    is  => 'rw',
);

sub BUILD {
    my $self = shift;
    debug "start " . $self->name;

    if (my $init = $self->can('init')) {
        $init->($self);
    }
}

no Any::Moose '::Role';
1;
