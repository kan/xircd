use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

# this module requires one xs: Net::SSLeay
requires 'Exporter' => 5.63;
requires 'Devel::Caller::Perl' => 1.4;

requires 'Any::Moose' => 0.08;

requires 'POE' => 1.004;
requires 'POE::Component::Server::IRC' => 1.38;

recommends 'Mouse' => 0.21;
recommends 'JSON' => 2.12;
recommends 'POE::Component::Jabber' => 2.03;
recommends 'POE::Component::Client::HTTP' => 0.88;
recommends 'XML::Feed';
recommends 'XML::Feed::Deduper';
recommends 'URI';

build_requires 'Test::More';
install_script('xircd');
author_tests('xt');
auto_include;
WriteAll;
