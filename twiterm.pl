use strict;
use warnings;

use FindBin;
use lib File::Spec->catfile($FindBin::Bin, 'lib');
use Term::ReadLine;
use Try::Tiny;
use Twiterm;
use YAML qw/DumpFile LoadFile/;

my $twiterm = new Twiterm();

my $config_path = $ARGV[0] || 'twiterm-config.yaml';
# An example of twiterm-config.yaml:
# ---
# accounts:
#   MyTwitter:
#     service: twitter
#     username: hogehoge
#     password: ********
# pages:
#   - name: friends' timeline
#     account_id: MyTwitter
#     timeline: friends
#   - name: mentions
#     account_id: MyTwitter
#     timeline: mentions
my $config;
$config = try {
    LoadFile($config_path);
} catch {
    create_default_config();
};

$twiterm->run($config);

sub create_default_config {
    my $config;
    my $term = new Term::ReadLine;

    my $use_twitter;
  USE_TWITTER:
    while (defined (my $input = $term->readline('use Twitter? (y/n) [y]: '))) {
        if ($input eq '' || lc($input) =~ /^(y|n)$/) {
            $use_twitter = lc($input) eq 'n' ? 0 : 1;
            last USE_TWITTER;
        }
    }
    while ($use_twitter) {
        my $account = sprintf 'Twitter%d', scalar keys %{$config->{accounts}};
        print "account: $account\n";
        my ($username, $password);
      USERNAME:
        while (defined ($username = $term->readline('username: '))) {
            last USERNAME if $username =~ /^\w+$/;
        }
      PASSWORD:
        while (defined ($password = $term->readline('password: '))) {
            last PASSWORD if $password =~ /^.+$/;
        }
        $config->{accounts}{$account} = {
            service  => q/twitter/,
            username => $username,
            password => $password,
        };
        push @{$config->{pages}}, {
            name       => qq/$account home timeline/,
            account_id => $account,
            timeline   => q/friends/,
        };
        push @{$config->{pages}}, {
            name       => qq/$account mentions/,
            account_id => $account,
            timeline   => q/mentions/,
        };

      USE_OTHER:
        while (defined (my $input = $term->readline('use other account? (y/n) [n]: '))) {
            if ($input eq '' || lc($input) =~ /^(y|n)$/) {
                $use_twitter = lc($input) eq 'y' ? 1 : 0;
                last USE_OTHER;
            }
        }
    }

    my $use_wassr;
  USE_WASSR:
    while (defined (my $input = $term->readline('use Wassr? (y/n) [y]: '))) {
        if ($input eq '' || lc($input) =~ /^(y|n)$/) {
            $use_wassr = lc($input) eq 'n' ? 0 : 1;
            last USE_WASSR;
        }
    }
    if ($use_wassr) {
        my $account = 'Wassr';
        print "account: $account\n";
        my ($username, $password);
      USERNAME:
        while (defined ($username = $term->readline('username: '))) {
            last USERNAME if $username =~ /^\w+$/;
        }
      PASSWORD:
        while (defined ($password = $term->readline('password: '))) {
            last PASSWORD if $password =~ /^.+$/;
        }
        $config->{accounts}{$account} = {
            service  => q/wassr/,
            username => $username,
            password => $password,
        };
        push @{$config->{pages}}, {
            name       => qq/$account friends timeline/,
            account_id => $account,
            timeline   => q/friends/,
        };
        push @{$config->{pages}}, {
            name       => qq/$account replies/,
            account_id => $account,
            timeline   => q/mentions/,
        };
    }

    DumpFile($config_path, $config);

    return $config;
}
