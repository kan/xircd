package XIRCD;
use Any::Moose;
with any_moose('X::Getopt');

our $VERSION = '0.0.1';

use Coro;
use Coro::AnyEvent;
use AnyEvent;
use AnyEvent::Impl::POE;
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

    print "run with ", (Any::Moose::moose_is_preferred() ? 'Moose' : 'Mouse'), "\n";

    my $done = AnyEvent->condvar;

    my $config = YAML::LoadFile($self->config) or die $!;

    XIRCD::Server->run($config->{ircd});

    for my $component ( @{$config->{components}} ) {
        my $module = 'XIRCD::Component::' . $component->{module};
        Any::Moose::load_class($module);
        my $channel = '#' . lc($component->{module});
        $module->run( 
            name    => lc($component->{module}),
            channel => $channel,
            %{$component} 
        );
        print "spawned $module at $channel\n";
    }

    # are you running?
    my $w = AnyEvent->timer(
        after    => 0.5,
        interval => 1,
        cb       => sub {
            warn "running\n";
        }
    );

    local $SIG{INT} = sub { die "SIGINT" };
    $done->recv;
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
