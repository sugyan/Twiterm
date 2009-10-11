use strict;
use warnings;

use FindBin;
use lib File::Spec->catfile($FindBin::Bin, 'lib');
use Getopt::Long;
use Twiterm;

my $usage = "usage: perl $0 --username=<username> --password=<password>\n";
GetOptions(
    'username=s' => \my $username,
    'password=s' => \my $password,
) or die;
warn $usage and die if (!defined($username) or !defined($password));

my $twiterm = new Twiterm(
    config => {
        username => $username,
        password => $password,
        pages => [ {
            name     => q/friends' timeline/,
            timeline => 'friends',
        }, {
            name     => 'mentions',
            timeline => 'mentions',
        } ],
    },
);
$twiterm->run();
