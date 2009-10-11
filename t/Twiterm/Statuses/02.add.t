use Test::More tests => 3;

use Twiterm::Statuses;

my $class = 'Twiterm::Statuses';
can_ok $class, '_add';

my $statuses = new_ok $class, [
    username => 'username',
    password => 'password',
];

ok !($statuses->friends);
