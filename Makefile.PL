use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

# MooseX::POE 0.07 does not works with MooseX::AttributeHelper 0.08
# SEE ALSO:  http://d.hatena.ne.jp/tokuhirom/20080605/1212663745
requires 'MooseX::AttributeHelpers'  => 0.09;

requires 'Exporter' => 5.63;
requires 'Devel::Caller' => 2.03;
requires 'self' => 0.32;

requires 'Moose'       => 0.72;
requires 'MooseX::POE' => 0.10;

requires 'POE' => 1.003;
requires 'POE::Component::Server::IRC' => 1.38;

build_requires 'Test::More';
install_script('xircd');
author_tests('xt');
use_test_base;
auto_include;
WriteAll;
