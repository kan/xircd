package XIRCD::Base;
use strict;
use warnings;
use base 'Exporter';
use Any::Moose;
use POE;

our @EXPORT = qw/run event alias/;

my $event_map;

sub import {
    my $pkg = caller(0);
    __PACKAGE__->_setup($pkg);
    __PACKAGE__->export_to_level(1);
}

sub _setup {
    my ($class, $pkg) = @_;

    # XXX this is silly. mouse does not have enough feature!
    if (Any::Moose::is_moose_loaded) {
        $pkg->meta->add_attribute(
            poe_session_id => (
                is => 'rw',
                isa => 'Str',
            )
        );
    } else {
        my $meta = Mouse::Meta::Class->initialize($pkg);
        Mouse::Meta::Attribute->create(
            $meta, 'poe_session_id' => (
                is => 'rw',
                isa => 'Str',
            )
        );
    }
}

sub run {
    my $class = shift;
    my $self = $class->new(@_);

    POE::Session->create(
        inline_states => {
            _start => sub {
                $self->poe_session_id( $_[SESSION]->ID );
                $self->START();
            },
        },
        object_states => [
            $self => +{
                map { $_ => "__event_$_" }
                @{ $event_map->{$class} },
            },
        ],
    );
}

sub event {
    my $pkg = caller(0);
    my ( $name, $cb ) = @_;

    $pkg->meta->add_method(
        "__event_$name" => $cb,
    );
    push @{$event_map->{$pkg}}, $name;
}

sub alias {
    my ($self, $alias) = @_;
    $poe_kernel->alias_set($alias);
}

1;
