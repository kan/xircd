use strict;
use Test::More;
plan skip_all => 'cannot load Test::Perl::Critic' unless eval q{ use Test::Perl::Critic -profile => 'xt/perlcriticrc'; 1; };
all_critic_ok('lib');
