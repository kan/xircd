# $Id: ServerHandle.pm 53 2008-07-28 03:03:04Z larwan $
package POE::Component::SSLify::ServerHandle;
use strict; use warnings;

# Initialize our version
use vars qw( $VERSION );
$VERSION = '0.15';

# Import the SSL death routines
use Net::SSLeay qw( die_now die_if_ssl_error );

# Ties the socket
sub TIEHANDLE {
	my ( $class, $socket, $ctx ) = @_;

	my $ssl = Net::SSLeay::new( $ctx ) or die_now( "Failed to create SSL $!" );

	my $fileno = fileno( $socket );

	Net::SSLeay::set_fd( $ssl, $fileno );

	my $err = Net::SSLeay::accept( $ssl ) and die_if_ssl_error( 'ssl accept' );

	my $self = bless {
		'ssl'		=> $ssl,
		'ctx'		=> $ctx,
		'socket'	=> $socket,
		'fileno'	=> $fileno,
	}, $class;

	return $self;
}

# Read something from the socket
sub READ {
	# Get ourself!
	my $self = shift;

	# Get the pointers to buffer, length, and the offset
	my( $buf, $len, $offset ) = \( @_ );

	# If we have no offset, replace the buffer with some input
	if ( ! defined $$offset ) {
		$$buf = Net::SSLeay::read( $self->{'ssl'}, $$len );

		# Are we done?
		if ( defined $$buf ) {
			return length( $$buf );
		} else {
			# Nah, clear the buffer too...
			$$buf = "";
			return;
		}
	}

	# Now, actually read the data
	defined( my $read = Net::SSLeay::read( $self->{'ssl'}, $$len ) ) or return;

	# Figure out the buffer and offset
	my $buf_len = length( $$buf );

	# If our offset is bigger, pad the buffer
	if ( $$offset > $buf_len ) {
		$$buf .= chr( 0 ) x ( $$offset - $buf_len );
	}

	# Insert what we just read into the buffer
	substr( $$buf, $$offset ) = $read;

	# All done!
	return length( $read );
}

# Write some stuff to the socket
sub WRITE {
	# Get ourself + buffer + length + offset to write
	my( $self, $buf, $len, $offset ) = @_;

	# If we have nothing to offset, then start from the beginning
	if ( ! defined $offset ) {
		$offset = 0;
	}

	# We count the number of characters written to the socket
	my $wrote_len = Net::SSLeay::write( $self->{'ssl'}, substr( $buf, $offset, $len ) );

	# Did we get an error or number of bytes written?
	# Net::SSLeay::write() returns the number of bytes written, or -1 on error.
	if ( $wrote_len < 0 ) {
		# The normal syswrite() POE uses expects 0 here.
		return 0;
	} else {
		# All done!
		return $wrote_len;
	}
}

# Sets binmode on the socket
# Thanks to RT #27117
sub BINMODE {
	my $self = shift;
	if (@_) {
		my $mode = shift;
		binmode $self->{'socket'}, $mode;
	} else {
		binmode $self->{'socket'};
	}

	return;
}

# Closes the socket
sub CLOSE {
	my $self = shift;
	if ( defined $self->{'socket'} ) {
		Net::SSLeay::free( $self->{'ssl'} );
		close( $self->{'socket'} );
		undef $self->{'socket'};

		# do we need to do CTX_free?
		if ( exists $self->{'client'} ) {
			Net::SSLeay::CTX_free( $self->{'ctx'} );
		}
	}

	return 1;
}

# Add DESTROY handler
sub DESTROY {
	my $self = shift;

	# Did we already CLOSE?
	if ( defined $self->{'socket'} ) {
		# Guess not...
		$self->CLOSE();
	}

	return;
}

sub FILENO {
	my $self = shift;
	return $self->{'fileno'};
}

# Not implemented TIE's
sub READLINE {
	die 'Not Implemented';
}

sub PRINT {
	die 'Not Implemented';
}

# End of module
1;

__END__

=head1 NAME

POE::Component::SSLify::ServerHandle - server object for POE::Component::SSLify

=head1 ABSTRACT

	See POE::Component::SSLify

=head1 DESCRIPTION

	This is a subclass of Net::SSLeay::Handle because their read() and sysread()
	does not cooperate well with POE. They block until length bytes are read from the
	socket, and that is BAD in the world of POE...

	This subclass behaves exactly the same, except that it doesn't block :)

=head2 DIFFERENCES

	This subclass doesn't know what to do with PRINT/READLINE, as they usually are not used in POE::Wheel operations...

=head1 SEE ALSO

L<POE::Component::SSLify>

=head1 AUTHOR

Apocalypse E<lt>apocal@cpan.orgE<gt>

=head1 PROPS

	Original code is entirely Rocco Caputo ( Creator of POE ) -> I simply
	packaged up the code into something everyone could use...

	From the PoCo::Client::HTTP code for blocking sockets =]
	# TODO - This code should probably become a POE::Kernel method,
    	# seeing as it's rather baroque and potentially useful in a number
    	# of places.

=head1 COPYRIGHT AND LICENSE

Copyright 2009 by Apocalypse/Rocco Caputo

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
