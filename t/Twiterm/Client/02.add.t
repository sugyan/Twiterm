use Test::More tests => 8;

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

    is_deeply ($client->{statuses}, {});
    is (scalar $client->friends('hoge'), 0);
    is (scalar $client->friends('fuga'), 0);

    $client->_add($client->{accounts}{hoge}{friends}, (
        [ {
            text => 'hogefugpiyo'
        }, {
            id     => 'id1',
            source => 'web',
            user   => {
                id => 'usr1',
            },
        } ]
    ));

    is (scalar keys %{$client->{statuses}}, 1);
    is (scalar $client->friends('hoge'), 1);
    is (scalar $client->friends('fuga'), 0);
}

# TODO: {
#     local $TODO = "not implemented";

#     my $client = $wassr->new();
#     $client->add_account('hoge', {
#         username => 'username1',
#         password => 'password1',
#     });
#     $client->add_account('fuga', {
#         username => 'username2',
#         password => 'password2',
#     });

#     ok !($client->friends('hoge'));
#     ok !($client->friends('fuga'));
# }
