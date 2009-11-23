use Test::More tests => 14;

use Twiterm::Client::TwitterClient;
use Twiterm::Client::WassrClient;

my $twitter = 'Twiterm::Client::TwitterClient';
my $wassr   = 'Twiterm::Client::WassrClient';
can_ok $twitter, '_add';
can_ok $wassr,   '_add';

{
    my $client = $twitter->new();
    $client->add_account('hoge', {
        username => 'username1',
        password => 'password1',
    });
    $client->add_account('fuga', {
        username => 'username2',
        password => 'password2',
    });

    is (scalar @{$client->friends('hoge')}, 0);
    is (scalar @{$client->friends('fuga')}, 0);

    $client->_add($client->{accounts}{hoge}{friends}, (
        [ {
            text => 'hogefugpiyo111',
        }, {
            id     => 'id1',
            source => 'web',
            user   => {
                id => 'usr1',
            },
        } ]
    ));

    is (scalar @{$client->friends('hoge')}, 1);
    is (scalar @{$client->friends('fuga')}, 0);

    $client->_add($client->{accounts}{hoge}{friends}, (
        [ {
            text => 'hogefugpiyo222',
        }, {
            id     => 'id2',
            source => 'web',
            user   => {
                id => 'usr1',
            },
        } ]
    ));

    is (scalar @{$client->friends('hoge')}, 2);
    is (scalar @{$client->friends('fuga')}, 0);
}

{
    my $client = $wassr->new();
    $client->add_account('hoge', {
        username => 'username1',
        password => 'password1',
    });
    $client->add_account('fuga', {
        username => 'username2',
        password => 'password2',
    });

    is (scalar @{$client->friends('hoge')}, 0);
    is (scalar @{$client->friends('fuga')}, 0);

    $client->_add($client->{accounts}{hoge}{friends}, (
        {
            text    => 'hogefugpiyo111',
            rid     => 'id1',
        },
    ));

    is (scalar @{$client->friends('hoge')}, 1);
    is (scalar @{$client->friends('fuga')}, 0);

    $client->_add($client->{accounts}{hoge}{friends}, (
        {
            text    => 'hogefugpiyo222',
            rid     => 'id2',
        },
    ));

    is (scalar @{$client->friends('hoge')}, 2);
    is (scalar @{$client->friends('fuga')}, 0);
}
