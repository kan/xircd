use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

requires 'Exporter' => 5.63;
requires 'Devel::Caller::Perl' => 1.4;

requires 'Any::Moose' => 0.06;

requires 'POE' => 1.004;
requires 'POE::Component::Server::IRC' => 1.38;

recommends 'JSON' => 2.12;
recommends 'POE::Component::Jabber' => 2.03;
recommends 'POE::Component::Client::HTTP' => 0.88;

build_requires 'Test::More';
install_script('xircd');
author_tests('xt');
use_test_base;
auto_include;
WriteAll;
