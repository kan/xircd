use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

requires 'Exporter' => 5.63;
requires 'Devel::Caller' => 2.03;
requires 'self' => 0.32;

requires 'Moose'       => 0.72;

requires 'POE' => 1.003;
requires 'POE::Component::Server::IRC' => 1.38;

build_requires 'Test::More';
install_script('xircd');
author_tests('xt');
use_test_base;
auto_include;
WriteAll;
