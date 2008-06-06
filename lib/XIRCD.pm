package XIRCD;

use strict;
use warnings;
our $VERSION = '0.01';

use POE;
use POE::Component::TSTP;
use UNIVERSAL::require;
use Getopt::Long;
use YAML;

use XIRCD::Server;


sub bootstrap {
    my $class = shift;

    GetOptions('--config=s' => \my $conf, '--quiet' => \my $quiet);
    $conf or die "Usage: xircd.pl --config=config.yaml\n";

    my $config = YAML::LoadFile($conf) or die $!;

    if ($quiet) {
        close STDIN;
        close STDOUT;
        close STDERR;
        exit if fork;
    } else {
        # for Ctrl-Z
        POE::Component::TSTP->create();
    }

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
