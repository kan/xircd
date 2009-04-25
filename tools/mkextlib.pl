use strict;
use warnings;
use YAML::Tiny;
use FindBin;

my $meta = YAML::Tiny->read("$FindBin::Bin/../META.yml")->[0];
&main;exit;

sub main {
    install('requires');
    install('recommends');
}

sub install {
    my $key = shift;
    while (my ($mod, $ver) = each %{$meta->{$key}}) {
        system "perl -MCPAN -Mlocal::lib=--self-contained,extlib -e 'CPAN::install($mod)'";
    }
}

