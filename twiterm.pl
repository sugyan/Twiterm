use strict;
use warnings;

use FindBin;
use lib File::Spec->catfile($FindBin::Bin, 'lib');
use Twiterm;
use YAML 'LoadFile';

my $config_path = $ARGV[0] || 'config.yaml';
# An example of config.yaml:
# ---
# access_token: *************************************************
# access_token_secret: ******************************************
# pages:
#   - name: friends' timeline
#     timeline: friends
#   - name: mentions
#     timeline: mentions
my $config = LoadFile($config_path);
# TODO: configファイルが存在しない、もしくは不正な場合
Twiterm->new(config => $config)->run();
