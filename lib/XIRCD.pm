package XIRCD;
use Moose;

with 'MooseX::Daemonize';

our $VERSION = '0.0.1';

use POE;
use UNIVERSAL::require;
use YAML;

use XIRCD::Server;

has 'config' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has 'daemon' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

after 'start' => sub {
    my $self = shift;
    return unless $self->is_daemon;

    $self->bootstrap;
};


sub bootstrap {
    my $self = shift;

    $self->config or die "Usage: xircd.pl --config=config.yaml\n";

    my $config = YAML::LoadFile($self->config) or die $!;

    XIRCD::Server->new( %{$config->{ircd}} );

    for my $component ( @{$config->{components}} ) {
        my $module = 'XIRCD::Component::' . $component->{module};
        $module->require or die $@;
        $module->new( 
            name    => lc($component->{module}),
            channel => '#' . lc($component->{module}),
            %{$component} 
        );
    }

    POE::Kernel->run;
}

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
