package XIRCD;

use strict;
use warnings;
our $VERSION = '0.01';
use base qw/Class::Accessor::Fast/;

__PACKAGE__->mk_accessors('config');

use POE;
use Config::Pit;
use UNIVERSAL::require;

use XIRCD::Server;

sub bootstrap {
    my $class = shift;

    my $config = $class->_load_conf;

    XIRCD::Server->spawn( $config->{ircd} );

    for my $plugin ( @{$config->{plugins}} ) {
        my $module = $plugin->{module};
        $module->require;
        $module->spawn( $plugin );
    }

    POE::Kernel->run;
}

sub _load_conf {
    return pit_get(
        'XIRCD', require => {
            ircd => {
                port            => 6667,
                server_nick     => 'xircd',
                client_encoding => 'utf-8',
                no_nick_tweaks  => 1,
                plugins         => [
                    { module => 'Time', channel => '#time' },
                ],
            }
        }
    );
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
