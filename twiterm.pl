use strict;
use warnings;

use FindBin;
use lib File::Spec->catfile($FindBin::Bin, 'lib');
use Net::Twitter::Lite;
use Twiterm;
use YAML qw/DumpFile LoadFile/;

my $twiterm = new Twiterm();

my $config_path = $ARGV[0] || 'config.yaml';
# An example of config.yaml:
# ---
# account:
#   - service: twitter
#     id: MyTwitter
#     access_token: *************************************************
#     access_token_secret: ******************************************
# pages:
#   - name: friends' timeline
#     account_id: MyTwitter
#     timeline: friends
#   - name: mentions
#     account_id: MyTwitter
#     timeline: mentions
my $config = eval {
    LoadFile($config_path);
};
if ($@) {
    my $ntl = Net::Twitter::Lite->new(%$twiterm);
    my $auth_url = $ntl->get_authorization_url;
    print "Authorize this app at\n$auth_url\nand enter the PIN# :";
    # wait for input
    my $pin = <STDIN>;
    chomp $pin;

    my($access_token, $access_token_secret) = $ntl->request_access_token(verifier => $pin);
    $config = {
        account => [{
            id       => 'MyTwitter',
            service  => 'twitter',
            access_token        => $access_token,
            access_token_secret => $access_token_secret,
        }],
        pages => [{
            name       => 'home timeline',
            account_id => 'MyTwitter',
            timeline   => 'friends',
        }, {
            name       => 'mentions',
            account_id => 'MyTwitter',
            timeline   => 'mentions',
        }],
    };
    DumpFile($config_path, $config);
}

$twiterm->run($config);
