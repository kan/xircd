# $Id: ClientHandle.pm 53 2008-07-28 03:03:04Z larwan $
package POE::Component::SSLify::ClientHandle;
use strict; use warnings;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.15';

# Import the SSL death routines
use Net::SSLeay qw( die_now die_if_ssl_error );

# We inherit from ServerHandle
use vars qw( @ISA );
require POE::Component::SSLify::ServerHandle;
@ISA = qw( POE::Component::SSLify::ServerHandle );

# Override TIEHANDLE because we create a CTX
sub TIEHANDLE {
	my ( $class, $socket, $version, $options, $ctx ) = @_;

	# create a context, if necessary
	if ( ! defined $ctx ) {
		$ctx = POE::Component::SSLify::createSSLcontext( undef, undef, $version, $options );
	}

	my $ssl = Net::SSLeay::new( $ctx ) or die_now( "Failed to create SSL $!" );

	my $fileno = fileno( $socket );

	Net::SSLeay::set_fd( $ssl, $fileno );   # Must use fileno

	my $resp = Net::SSLeay::connect( $ssl ) or die_if_ssl_error( 'ssl connect' );

	my $self = bless {
		'ssl'		=> $ssl,
		'ctx'		=> $ctx,
		'socket'	=> $socket,
		'fileno'	=> $fileno,
		'client'	=> 1,
	}, $class;

	return $self;
}

# End of module
1;

__END__

=head1 NAME

POE::Component::SSLify::ClientHandle - client object for POE::Component::SSLify

=head1 ABSTRACT

	See POE::Component::SSLify::ServerHandle

=head1 DESCRIPTION

	This is a subclass of ServerHandle to accomodate clients setting custom context objects.

=head1 SEE ALSO

L<POE::Component::SSLify>

L<POE::Component::SSLify::ServerHandle>

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
