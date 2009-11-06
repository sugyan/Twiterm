use Test::More tests => 1;

use Twiterm::Statuses;

my $class = 'Twiterm::Statuses';
my $statuses = new_ok $class, [
    accounts => [ {
        id       => '1',
        service  => 'twitter',
        username => 'username',
        password => 'password',
    } ],
];
