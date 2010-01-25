package XIRCD;
use Any::Moose;

our $VERSION = '0.0.1';

use Coro;
use Coro::AnyEvent;
use AnyEvent;
use YAML;
use Getopt::Long;
use Pod::Usage;

use XIRCD::Server;

{
    my $_context;
    sub context { $_context }
    sub set_context { $_context = $_[1] }
}

has server => (
    is => 'rw',
    isa => 'XIRCD::Server',
);

has config => (
    is       => 'rw',
    isa      => 'HashRef',
    required => 1,
);

sub new_with_options {
    my $class = shift;
    my @args = @_ == 1 ? %{$_[0]} : @_;

    my $conffile = 'config.yaml';
    GetOptions(
        'c|config=s' => \$conffile,
    );
    pod2usage() unless $conffile;
    unless (-f $conffile) {
        Carp::croak "configuration file not found: $conffile";
    }

    print "run with ", (Any::Moose::moose_is_preferred() ? 'Moose' : 'Mouse'), "\n";

    my $config = YAML::LoadFile($conffile) or die $!;
    return $class->new(config => $config, @args);
}

sub BUILD {
    my $self = shift;

    XIRCD->set_context($self);

    my $config = $self->config();

    my $server = XIRCD::Server->new($config->{ircd});
    $self->server( $server );

    my @coros;
    for my $component ( @{$config->{components}} ) {
        # please wait main loop
        push @coros, async {
            my $module = 'XIRCD::Component::' . $component->{module};
            Any::Moose::load_class($module);
            my $obj = $module->new($component);
            $server->register($obj);
            print "spawned $module at @{[ $obj->channel ]}\n";
        };
    }
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

XIRCD -

=head1 SYNOPSIS

    % xircd -c config.yaml

=head1 DESCRIPTION

XIRCD is

=head1 AUTHOR

Kan Fushihara E<lt>kan at mobilefactory do jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
