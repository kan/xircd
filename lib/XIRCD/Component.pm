package XIRCD::Component;
use Any::Moose;
use Devel::Caller::Perl qw(called_args);
use base 'Exporter';

our @EXPORT = qw(self debug get_args yield delay post publish_message publish_notice);

# XXX this is silly. mouse does not have enough feature!
sub init_class {
    my $klass = shift;
    my $meta  = any_moose('::Meta::Class')->initialize($klass);
    $meta->superclasses( any_moose('::Object') )
      unless $meta->superclasses;

    no strict 'refs';
    no warnings 'redefine';
    *{ $klass . '::meta' } = sub { $meta };
}

sub import {
    strict->import;
    warnings->import;

    my $class = shift;
    my $mode = shift;
    my $pkg = caller(0);
    unless ($mode && $mode eq '-nocomponent') {
        if (Any::Moose::is_moose_loaded) {
            Moose->import({ into_level => 1 });
        } else {
            init_class($pkg);
            Mouse->export_to_level(1);
        }
        XIRCD::Base->_setup(scalar caller(0));
        XIRCD::Base->export_to_level(1);
        any_moose('Util')->can('apply_all_roles')->(
            scalar caller(0), 'XIRCD::Role'
        );
    }
    $class->export_to_level(1);
}

sub self () {
    (called_args(0))[0];
}

sub debug (@) { ## no critic.
    print @_, "\n" if $ENV{XIRCD_DEBUG};
}

sub get_args { return (called_args(0))[10..20]; }

sub yield (@) { ## no critic.
    POE::Kernel->yield(@_);
}

sub delay (@) { ## no critic.
    POE::Kernel->delay(@_);
}

sub post (@) { ## no critic.
    POE::Kernel->post(@_);
}

sub publish_message ($$) {  ## no critic.
    my $_self = (called_args(0))[0];
    my ($nick, $text) = @_;

    post ircd => '_publish_message' => $nick, $_self->channel, $text;
}

sub publish_notice ($) {  ## no critic.
    my $_self = (called_args(0))[0];
    my ($text,) = @_;

    post ircd => '_publish_notice' => $_self->channel, $text;
}

1;
