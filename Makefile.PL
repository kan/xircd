use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

# MooseX::POE 0.07 does not works with MooseX::AttributeHelper 0.08
# SEE ALSO:  http://d.hatena.ne.jp/tokuhirom/20080605/1212663745
requires 'MooseX::AttributeHelpers'  => 0.09;

requires 'UNIVERSAL::require';
requires 'POE';
requires 'Sub::Exporter';
requires 'Devel::Caller';
requires 'self';

requires 'Moose'       => 0.50;
requires 'MooseX::POE' => 0.07;
requires 'MooseX::Daemonize' => 0.07;

build_requires 'Test::More';
install_script('xircd');
use_test_base;
auto_include;
WriteAll;
