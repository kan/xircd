package XIRCD;
use Any::Moose;
with any_moose('X::Getopt');

our $VERSION = '0.0.1';

use POE;
use YAML;

use XIRCD::Server;

has 'config' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
    trigger  => sub {
        my $self = shift;
        unless (-f $self->config) {
            Carp::croak 'configuration file not found: ' . $self->config;
        }
    }
);

sub bootstrap {
    my $self = shift;

    print "run with ", (Any::Moose::is_moose_loaded() ? 'Moose' : 'Mouse'), "\n";

    my $config = YAML::LoadFile($self->config) or die $!;

    XIRCD::Server->run($config->{ircd});

    for my $component ( @{$config->{components}} ) {
        my $module = 'XIRCD::Component::' . $component->{module};
        Any::Moose::load_class($module);
        $module->run( 
            name    => lc($component->{module}),
            channel => '#' . lc($component->{module}),
            %{$component} 
        );
    }

    POE::Kernel->run;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

XIRCD -

=head1 SYNOPSIS

  use XIRCD;

=head1 DESCRIPTION

XIRCD is

=head1 AUTHOR

Kan Fushihara E<lt>kan at mobilefactory do jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
