package XIRCD::Role::Component;
use Any::Moose '::Role';
use XIRCD::Util qw/debug/;

has name => (
    isa => 'Str',
    is  => 'rw',
    default => sub {
        my $self = shift;
        my $proto = ref $self || $self;
        (my $moniker = $proto) =~ s/^.+:://;
        lc($moniker);
    },
);

has channel => (
    isa => 'Str',
    is  => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        '#' . $self->name;
    },
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
