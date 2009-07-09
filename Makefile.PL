use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

requires 'Exporter' => 5.63;
requires 'Devel::Caller::Perl' => 1.4;

requires 'Any::Moose' => 0.08;

requires 'POE' => 1.004;
requires 'POE::Component::Server::IRC' => 1.38;

requires 'AnyEvent' => 4.8;
requires 'AnyEvent::HTTP' => 1.4;
requires 'JSON' => 2.12;
requires 'Coro' => 5.151;

recommends 'Mouse' => 0.21;
recommends 'POE::Component::Jabber' => 2.03;
recommends 'XML::Feed';
recommends 'XML::Feed::Deduper';
recommends 'URI';

build_requires 'Test::More';
install_script('xircd');
author_tests('xt');
auto_include;
WriteAll;
