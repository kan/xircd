package XIRCD::Component::Twitter;
use MooseX::POE;

with qw(MooseX::POE::Aliased);

use POE qw(Component::Client::Twitter);

has 'config' => (
    isa => 'HashRef',
    is  => 'rw',
);

has 'twitter' => (
    isa     => 'POE::Component::Client::Twitter',
    is      => 'rw',
);

sub debug(@) { ## no critic.
    print @_ if $ENV{XIRCD_DEBUG};
}

sub get_args(@) { ## no critic.
    return @_[9..19];
}

sub START {
    my $self = shift;

    $self->alias('twitter');

    debug "start twitter\n";
    $self->twitter(POE::Component::Client::Twitter->spawn(%{ $self->config->{twitter} }));
    $self->twitter->yield('register');

    POE::Kernel->post( ircd => 'join_channel', $self->config->{channel} );
    POE::Kernel->delay('read_twitter_friend_timeline', 5);
}

event read_twitter_friend_timeline => sub {
    my $self = shift;

    debug "read twitter";
    $self->twitter->yield('friend_timeline');
};

event 'twitter.friend_timeline_success' => sub {
    my $self = shift;

    debug "get friend timeline";
    my ( $ret, ) = get_args(@_);
    for my $line ( reverse @{ $ret || [] } ) {
        POE::Kernel->post(
            ircd => publish_message => 
                $line->{user}->{screen_name},
                $self->config->{channel}, 
                $line->{text},
        );
    }

    POE::Kernel->delay('read_twitter_friend_timeline', $self->config->{twitter}->{retry});
};

event 'twitter.response_error' => sub {
    my $self = shift;
    my ($res,) = get_args(@_);

    use Data::Dumper;
    warn Dumper($res);
};


1;

