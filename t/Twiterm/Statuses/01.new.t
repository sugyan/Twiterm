use Test::More tests => 1;

use Twiterm::Statuses;

my $class = 'Twiterm::Statuses';
my $statuses = new_ok $class, [
    twitter_params => {
        username => 'username',
        password => 'password',
    },
];
