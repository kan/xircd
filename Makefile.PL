use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

# MooseX::POE 0.07 does not works with MooseX::AttributeHelper 0.08
# SEE ALSO:  http://d.hatena.ne.jp/tokuhirom/20080605/1212663745
requires 'MooseX::AttributeHelpers'  => 0.09;

requires 'UNIVERSAL::require';
requires 'POE';

requires 'POE::Component::TSTP';
requires 'Moose'       => 0.48;
requires 'MooseX::POE' => 0.07;

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
