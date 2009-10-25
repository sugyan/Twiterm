use strict;
use warnings;

use AnyEvent;
use AnyEvent::Wassr;
use Encode 'encode_utf8';

my $wassr = AnyEvent::Wassr->new(
    username => '<your user id>',
    password => '<password>',
);

sub print_statuses {
    my ($wassr, @statuses) = @_;
    for my $status (reverse @statuses) {
        my $user = encode_utf8 $status->{user}{screen_name};
        my $text = encode_utf8 $status->{text};
        print "$user: $text\n";
    }
}

$wassr->reg_cb(
    friends_timeline => \&print_statuses,
    replies          => \&print_statuses,
    error => sub {
        my ($wassr, $error) = @_;
        warn "Error: $error\n";
    },
);

$wassr->receive_statuses_friends(2);
$wassr->receive_statuses_replies(1);
$wassr->start;

my $cv = AE::cv;
my $w = AE::io *STDIN, 0, sub {
    my $input = scalar <STDIN>;
    chomp($input);
    $wassr->update_status(
        $input, sub {
            my ($wassr, $js_status, $error) = @_;
            if (defined $error) {
                warn "update error: $error\n";
            } else {
                my $text = encode_utf8 $js_status->{text};
                print qq/update success! "$text"\n/;
            }
        },
    );
};
$cv->recv;
