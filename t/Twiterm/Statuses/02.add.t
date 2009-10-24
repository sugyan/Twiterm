use Test::More tests => 2;

use Twiterm::Statuses;

my $class = 'Twiterm::Statuses';
can_ok $class, '_add';

my $statuses = $class->new(
    twitter_params => {
        username => 'username',
        password => 'password',
    },
);

ok !($statuses->friends);
