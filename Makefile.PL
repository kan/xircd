use inc::Module::Install;
name 'XIRCD';
all_from 'lib/XIRCD.pm';

requires $_ for (qw/ /);

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
