package XIRCD::Util;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw/debug/;

sub debug (@) { ## no critic.
    print @_, "\n" if $ENV{XIRCD_DEBUG};
}

1;
