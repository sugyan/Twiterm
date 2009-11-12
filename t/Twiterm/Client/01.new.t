use Test::More tests => 2;

use Twiterm::Client::TwitterClient;
use Twiterm::Client::WassrClient;

my $twitter = 'Twiterm::Client::TwitterClient';
my $wassr   = 'Twiterm::Client::WassrClient';
new_ok $twitter, [
    delegate  => $self,
    update_cb => \&_update_done,
];
new_ok $wassr, [
    delegate  => $self,
    update_cb => \&_update_done,
];
