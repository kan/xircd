package XIRCD::Role::Dedup;
use Any::Moose '::Role';
use DB_File;

has 'deduper' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {
        tie my %hash, 'DB_File';
        \%hash;
    },
);

no Any::Moose '::Role';
