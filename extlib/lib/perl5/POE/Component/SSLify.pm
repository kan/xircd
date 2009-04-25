# $Id: SSLify.pm 53 2008-07-28 03:03:04Z larwan $
package POE::Component::SSLify;
use strict; use warnings;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.15';

# We need Net::SSLeay or all's a failure!
BEGIN {
	eval { require Net::SSLeay };

	# Check for errors...
	if ( $@ ) {
		# Oh boy!
		die $@;
	} else {
		# Check to make sure the versions are what we want
		if ( ! (	defined $Net::SSLeay::VERSION and
				$Net::SSLeay::VERSION =~ /^1\.3/ ) ) {
			warn 'Please upgrade Net::SSLeay to v1.30+ installed: v' . $Net::SSLeay::VERSION;
		}

		# Finally, load our subclass :)
		require POE::Component::SSLify::ClientHandle;
		require POE::Component::SSLify::ServerHandle;

		# Initialize Net::SSLeay
		Net::SSLeay::load_error_strings();
		Net::SSLeay::SSLeay_add_ssl_algorithms();
		Net::SSLeay::randomize();

		# set nonblocking mode?
		if ( ! defined &NONBLOCKING ) { *NONBLOCKING = sub () { 0 } }
	}
}

# Do the exporting magic...
require Exporter;
use vars qw( @ISA @EXPORT_OK );
@ISA = qw( Exporter );
@EXPORT_OK = qw( Client_SSLify Server_SSLify SSLify_Options SSLify_GetCTX SSLify_GetCipher SSLify_GetSocket SSLify_ContextCreate );

# Bring in some socket-related stuff
use Symbol qw( gensym );
use POSIX qw( F_GETFL F_SETFL O_NONBLOCK EAGAIN EWOULDBLOCK );

# We need the server-side stuff
use Net::SSLeay qw( die_now die_if_ssl_error );

# The server-side CTX stuff
my $ctx = undef;

# Helper sub to set blocking on a handle
sub Set_Blocking {
	my $socket = shift;

	# skip this? ( experimental )
	return $socket if NONBLOCKING();

	# Net::SSLeay needs blocking for setup.
	#
	# ActiveState Perl 5.8.0 dislikes the Win32-specific code to make
	# a socket blocking, so we use IO::Handle's blocking(1) method.
	# Perl 5.005_03 doesn't like blocking(), so we only use it in
	# 5.8.0 and beyond.
	if ( $] >= 5.008 and $^O eq 'MSWin32' ) {
		# From IO::Handle POD
		# If an error occurs blocking will return undef and $! will be set.
		if ( ! $socket->blocking( 1 ) ) {
			die "Unable to set blocking mode on socket: $!";
		}
	} else {
		# Make the handle blocking, the POSIX way.
		if ( $^O ne 'MSWin32' ) {
			# Get the old flags
			my $flags = fcntl( $socket, F_GETFL, 0 ) or die "fcntl( $socket, F_GETFL, 0 ) fails: $!";

			# Okay, we patiently wait until the socket turns blocking mode
			until( fcntl( $socket, F_SETFL, $flags & ~O_NONBLOCK ) ) {
				# What was the error?
				if ( ! ( $! == EAGAIN or $! == EWOULDBLOCK ) ) {
					# Fatal error...
					die "fcntl( $socket, FSETFL, etc ) fails: $!";
				}
			}
		} else {
			# Darned MSWin32 way...
			# Do some ioctl magic here
			# 126 is FIONBIO ( some docs say 0x7F << 16 )
			my $flag = "0";
			ioctl( $socket, 0x80000000 | ( 4 << 16 ) | ( ord( 'f' ) << 8 ) | 126, $flag ) or die "ioctl( $socket, FIONBIO, $flag ) fails: $!";
		}
	}

	# All done!
	return $socket;
}

# Okay, the main routine here!
sub Client_SSLify {
	# Get the socket + version + options + ctx
	my( $socket, $version, $options, $ctx ) = @_;

	# Validation...
	if ( ! defined $socket ) {
		die "Did not get a defined socket";
	}

	# Set blocking on
	$socket = Set_Blocking( $socket );

	# Now, we create the new socket and bind it to our subclass of Net::SSLeay::Handle
	my $newsock = gensym();
	tie( *$newsock, 'POE::Component::SSLify::ClientHandle', $socket, $version, $options, $ctx ) or die "Unable to tie to our subclass: $!";

	# All done!
	return $newsock;
}

# Okay, the main routine here!
sub Server_SSLify {
	# Get the socket!
	my $socket = shift;
	my $custom_ctx = shift;

	# Validation...
	if ( ! defined $socket ) {
		die "Did not get a defined socket";
	}

	# If we don't have a ctx ready, we can't do anything...
	if ( ! defined $ctx and ! defined $custom_ctx ) {
		die 'Please do SSLify_Options() first ( or pass in a $ctx object )';
	}

	# Set blocking on
	$socket = Set_Blocking( $socket );

	# Now, we create the new socket and bind it to our subclass of Net::SSLeay::Handle
	my $newsock = gensym();
	tie( *$newsock, 'POE::Component::SSLify::ServerHandle', $socket, ( $custom_ctx || $ctx ) ) or die "Unable to tie to our subclass: $!";

	# All done!
	return $newsock;
}

sub SSLify_ContextCreate {
	# Get the key + cert + version + options
	my( $key, $cert, $version, $options ) = @_;

	return createSSLcontext( $key, $cert, $version, $options );
}

sub SSLify_Options {
	# Get the key + cert + version + options
	my( $key, $cert, $version, $options ) = @_;

	# sanity
	if ( ! defined $key or ! defined $cert ) {
		die 'no key/cert specified';
	}

	# Set the default
	if ( ! defined $options ) {
		$options = &Net::SSLeay::OP_ALL;
	}

	# set the context, possibly overwriting the previous one
	if ( defined $ctx ) {
		Net::SSLeay::CTX_free( $ctx );
		undef $ctx;
	}
	$ctx = createSSLcontext( $key, $cert, $version, $options );

	# all done!
	return 1;
}

sub createSSLcontext {
	my( $key, $cert, $version, $options ) = @_;

	my $context;
	if ( defined $version and ! ref $version ) {
		if ( $version eq 'sslv2' ) {
			$context = Net::SSLeay::CTX_v2_new();
		} elsif ( $version eq 'sslv3' ) {
			$context = Net::SSLeay::CTX_v3_new();
		} elsif ( $version eq 'tlsv1' ) {
			$context = Net::SSLeay::CTX_tlsv1_new();
		} elsif ( $version eq 'default' ) {
			$context = Net::SSLeay::CTX_new();
		} else {
			die "unknown SSL version: $version";
		}
	} else {
		$context = Net::SSLeay::CTX_new();
	}
	if ( ! defined $context ) {
		die_now( "Failed to create SSL_CTX $!" );
		return;
	}

	# do we need to set options?
	if ( defined $options ) {
		Net::SSLeay::CTX_set_options( $context, $options ) and die_if_ssl_error( 'ssl ctx set options' );
	}

	# do we need to set key/etc?
	if ( defined $key ) {
		# Following will ask password unless private key is not encrypted
		Net::SSLeay::CTX_use_RSAPrivateKey_file( $context, $key, &Net::SSLeay::FILETYPE_PEM );
		die_if_ssl_error( 'private key' );
	}

	# Set the cert file
	if ( defined $cert ) {
		Net::SSLeay::CTX_use_certificate_file( $context, $cert, &Net::SSLeay::FILETYPE_PEM );
		die_if_ssl_error( 'certificate' );
	}

	# All done!
	return $context;
}

# Returns the server-side CTX in case somebody wants to play with it
sub SSLify_GetCTX {
	my $sock = shift;
	if ( ! defined $sock ) {
		return $ctx;
	} else {
		return tied( *$sock )->{'ctx'};
	}
}

# Gives you the cipher type of a SSLified socket
sub SSLify_GetCipher {
	my $sock = shift;
	return Net::SSLeay::get_cipher( tied( *$sock )->{'ssl'} );
}

# Gives you the "Real" Socket to play with
sub SSLify_GetSocket {
	my $sock = shift;
	return tied( *$sock )->{'socket'};
}

# End of module
1;

__END__

=head1 NAME

POE::Component::SSLify - Makes using SSL in the world of POE easy!

=head1 SYNOPSIS

=head2 Client-side usage

	# Import the module
	use POE::Component::SSLify qw( Client_SSLify );

	# Create a normal SocketFactory wheel or something
	my $factory = POE::Wheel::SocketFactory->new( ... );

	# Converts the socket into a SSL socket POE can communicate with
	eval { $socket = Client_SSLify( $socket ) };
	if ( $@ ) {
		# Unable to SSLify it...
	}

	# Now, hand it off to ReadWrite
	my $rw = POE::Wheel::ReadWrite->new(
		Handle	=>	$socket,
		...
	);

	# Use it as you wish...

=head2 Server-side usage

	# !!! Make sure you have a public key + certificate generated via Net::SSLeay's makecert.pl
	# excellent howto: http://www.akadia.com/services/ssh_test_certificate.html

	# Import the module
	use POE::Component::SSLify qw( Server_SSLify SSLify_Options );

	# Set the key + certificate file
	eval { SSLify_Options( 'server.key', 'server.crt' ) };
	if ( $@ ) {
		# Unable to load key or certificate file...
	}

	# Create a normal SocketFactory wheel or something
	my $factory = POE::Wheel::SocketFactory->new( ... );

	# Converts the socket into a SSL socket POE can communicate with
	eval { $socket = Server_SSLify( $socket ) };
	if ( $@ ) {
		# Unable to SSLify it...
	}

	# Now, hand it off to ReadWrite
	my $rw = POE::Wheel::ReadWrite->new(
		Handle	=>	$socket,
		...
	);

	# Use it as you wish...

=head1 ABSTRACT

	Makes SSL use in POE a breeze!

=head1 DESCRIPTION

This component represents the standard way to do SSL in POE.

=head1 NOTES

=head2 Socket methods doesn't work

The new socket this module gives you actually is some tied socket magic, so you cannot do stuff like
getpeername() or getsockname(). The only way to do it is to use SSLify_GetSocket and then operate on
the socket it returns.

=head2 Dying everywhere...

This module will die() if Net::SSLeay could not be loaded or it is not the version we want. So, it is recommended
that you check for errors and not use SSL, like so:

	eval { use POE::Component::SSLify };
	if ( $@ ) {
		$sslavailable = 0;
	} else {
		$sslavailable = 1;
	}

	# Make socket SSL!
	if ( $sslavailable ) {
		eval { $socket = POE::Component::SSLify::Client_SSLify( $socket ) };
		if ( $@ ) {
			# Unable to SSLify the socket...
		}
	}

=head2 Mixing Server/Client in the same program

	Some users have reported success, others failure when they tried to utilize SSLify in both roles. This
	would require more investigation, so please tread carefully if you need to use it!

=head2 Blocking mode

	Normally, Net::SSLeay requires the socket to be in blocking mode for the initial handshake to work. However,
	various users ( especially ASCENT, thanks! ) have reported success in setting nonblocking mode for clients.

	In order to enable nonblocking mode, you need to set the subroutine "NONBLOCKING" to a true value in this
	package.

		sub POE::Component::SSLify::NONBLOCKING { 1 }
		use POE::Component::SSLify;

	This is a global, and an EXPERIMENTAL feature! Please, pretty please report back to me your experience with
	this. Hopefully someday SSLify will be fully nonblocking, thanks to your help!

=head1 FUNCTIONS

=head2 Client_SSLify

	Accepts a socket, returns a brand new socket SSLified. Optionally accepts SSL
	context data.
		my $socket = shift;						# get the socket from somewhere
		$socket = Client_SSLify( $socket );				# the default
		$socket = Client_SSLify( $socket, $version, $options );		# sets more options for the context
		$socket = Client_SSLify( $socket, undef, undef, $ctx );		# pass in a custom context

	If $ctx is defined, SSLify will ignore other args. If $ctx isn't defined, SSLify
	will create it from the $version + $options parameters.

	Known versions:
		* sslv2
		* sslv3
		* tlsv1
		* default

	By default we use the version: default

	By default we don't set any options

	NOTE: The way to have a client socket with proper certificates set up is:
		my $socket = shift;	# get the socket from somewhere
		my $ctx = SSLify_ContextCreate( 'server.key', 'server.crt' );
		$socket = Client_SSLify( $socket, undef, undef, $ctx );

	BEWARE: If you passed in a CTX, SSLify will do Net::SSLeay::CTX_free( $ctx ) when the
	socket is destroyed. This means you cannot reuse contexts!

=head2 Server_SSLify

	Accepts a socket, returns a brand new socket SSLified
		my $socket = shift;	# get the socket from somewhere
		$socket = Server_SSLify( $socket );

	NOTE: SSLify_Options must be set first!

	Furthermore, you can pass in your own $ctx object if you desire. This allows you to set custom parameters
	per-connection, for example.
		my $socket = shift;	# get the socket from somewhere
		my $ctx = Net::SSLeay::CTX_new();
		# set various options on $ctx as desired
		$socket = Server_SSLify( $socket, $ctx );

	NOTE: You can use SSLify_GetCTX to modify the global, and avoid doing this on every connection if the
	options are the same...

=head2 SSLify_Options

	Accepts the location of the SSL key + certificate files and does it's job

	Optionally accepts the SSL version + CTX options
		SSLify_Options( $key, $cert, $version, $options );

	Known versions:
		* sslv2
		* sslv3
		* tlsv1
		* default

	By default we use the version: default

	By default we use the options: &Net::SSLeay::OP_ALL

=head2 SSLify_GetCTX

	Returns the server-side CTX in case you wanted to play around with it :)

	If passed in a socket, it will return that socket's $ctx instead of the global.
		my $ctx = SSLify_GetCTX();			# get the one set via SSLify_Options
		my $ctx = SSLify_GetCTX( $sslified_sock );	# get the one in the object

=head2 SSLify_GetCipher

	Returns the cipher used by the SSLified socket

	Example:
		print "SSL Cipher is: " . SSLify_GetCipher( $sslified_sock ) . "\n";

=head2 SSLify_GetSocket

	Returns the actual socket used by the SSLified socket, useful for stuff like getpeername()/getsockname()

	Example:
		print "Remote IP is: " . inet_ntoa( ( unpack_sockaddr_in( getpeername( SSLify_GetSocket( $sslified_sock ) ) ) )[1] ) . "\n";

=head2 SSLify_ContextCreate

	Accepts some options, and returns a brand-new SSL context object ( $ctx )
		my $ctx = SSLify_ContextCreate();
		my $ctx = SSLify_ContextCreate( $key, $cert );
		my $ctx = SSLify_ContextCreate( $key, $cert, $version, $options );

	Known versions:
		* sslv2
		* sslv3
		* tlsv1
		* default

	By default we use the version: default

	By default we don't set any options

	By default we don't use the SSL key + certificate files

=head1 EXPORT

	Stuffs all of the above functions in @EXPORT_OK so you have to request them directly

head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::SSLify

=head2 Websites

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-SSLify>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-SSLify>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-SSLify>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-SSLify>

=back

=head2 Bugs

Please report any bugs or feature requests to C<bug-poe-component-sslify at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-SSLify>.  I will be
notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SEE ALSO

L<POE>

L<Net::SSLeay>

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 PROPS

	Original code is entirely Rocco Caputo ( Creator of POE ) -> I simply
	packaged up the code into something everyone could use and accepted the burden
	of maintaining it :)

	From the PoCo::Client::HTTP code =]
	# TODO - This code should probably become a POE::Kernel method,
    	# seeing as it's rather baroque and potentially useful in a number
    	# of places.

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse/Rocco Caputo

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
