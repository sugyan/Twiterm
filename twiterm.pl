#!/opt/local/bin/perl
use strict;
use warnings;

use lib 'lib';
use Twiterm::Statuses;

use AnyEvent;
use Encode 'encode_utf8';
use Getopt::Long;
use Term::ANSIColor ':constants';
use Term::Screen;
use Term::ReadLine;
use Unicode::EastAsianWidth;

my $usage = "usage: $0 --username=<username> --password=<password>";
my ($username, $password);
GetOptions(
    'username=s' => \$username,
    'password=s' => \$password,
) or die;
warn "$usage\n" and die if (!defined($username) or !defined($password));
my $statuses = new Statuses(
    username => $username,
    password => $password,
);
my $screen = new Term::Screen;
my $status_help = ' (j)down (k)up (:)command (q)quit';
my ($row, $col) = ($screen->rows() - 3, $screen->cols() - 1);
my $offset = 0;
my $select = 0;
my $disp_mode = 0;

$screen->clrscr();
draw_status_line();

# 一定時間毎にupdateする
my $cv_timer = AnyEvent->condvar;
my $timer; $timer = AnyEvent->timer(
    after    => 0,
    interval => 60,
    cb       => sub {
        update();
        $cv_timer->send;
    },
);
$cv_timer->recv;

while (1) {
    my $cv = AnyEvent->condvar;
    my $io; $io = AnyEvent->io(
        fh   => \*STDIN,
        poll => 'r',
        cb   => sub {
            my $char = $screen->noecho()->getch();
            $cv->send($char);
        },
    );
    # キー入力待ち
    my $char = $cv->recv;

    last if $char eq 'q';
    if ($char eq 'j') {
        my $line = select_down();
        next if !defined $line;
        draw($line);
        draw_status_line();
    }
    if ($char eq 'k') {
        my $line = select_up();
        next if !defined $line;
        draw($line);
        draw_status_line();
    }
    if ($char =~ /(\x0A|\x0D)/) {
        $disp_mode = !$disp_mode;
        draw();
        draw_status_line();
    }
    update() if $char eq 'd';
    if ($char eq ':') {
        # ReadLineの前に一度$screenをundefにする
        undef $screen;
        command();
        $screen = new Term::Screen;
        draw();
        draw_status_line();
    }
    last if $char eq 'q';
}

sub draw_detail {
    $screen->clrscr();

    my $status = $statuses->statuses->[$offset + $select];
    $screen->at(0, 0)->puts($status->{user}->{screen_name})->clreol();
    $screen->at(1, 0)->puts(encode_utf8 $status->{user}->{name})->clreol();
    $screen->at(2, 0)->puts(encode_utf8 $status->{user}->{location})->clreol();
    $screen->at(3, 0)->puts($status->{user}->{url})->clreol();
    $screen->at(4, 0)->puts(encode_utf8 $status->{user}->{description})->clreol();
    $screen->at(5, 0)->puts($status->{user}->{protected} ? 'private' : 'public')->clreol();
    $screen->at(6, 0)->clreol();
    $screen->at(7, 0)->puts(scalar localtime $status->{created_at})->clreol();
    $screen->at(8, 0)->puts('from ' . encode_utf8 $status->{source})->clreol();
    $screen->at(9, 0)->puts(encode_utf8 $status->{text})->clreol();
}

sub draw {
    return unless @{$statuses->statuses};

    if ($disp_mode) {
        draw_detail(@_);
    } else {
        draw_list(@_);
    }
}

sub draw_list {
    my $target = shift;

    my @range = (0 .. $row);
    # $targetが指定されていればその前後のみを描画
    if (defined $target) {
        if ($target == -1) {
            $screen->at(0, 0)->il();
            $target++;
            draw_status_line();
        }
        if ($target == $row + 1) {
            $screen->at(0, 0)->dl();
            $target--;
            draw_status_line();
        }
        @range = ($target - 1, $target, $target + 1);
        shift @range if $target == 0;
        pop   @range if $target == $row;
    }
    # 各行の描画
    for my $line (@range) {
        my $status = $statuses->statuses->[$line + $offset];
        my $text;
        if (defined $status->{line}) {
            # 表示用にキャッシュしておく
            $text = $status->{line};
        } else {
            # ターミナル幅に合わせて1行以内に収まるように切る
            my @created_at = localtime $status->{created_at};
            my $status_text = sprintf '%02d/%02d %02d:%02d:%02d - @%s : ',
                $created_at[4] + 1, @created_at[3, 2, 1, 0], $status->{user}->{screen_name};
            my $width = length $status_text;
            for my $char (split //, $status->{text}) {
                $width += $char =~ /\p{InFullwidth}/ ? 2 : 1;
                last if $width > $col;
                $status_text .= $char;
            }
            $text = encode_utf8 $status_text;
            $status->{line} = $text;
        }
        $screen->at($line, 0);
        $screen->reverse() if ($select == $line);
        $screen->puts($text)->clreol()->normal();
    }
    $screen->at($row + 2, 0)->clreol();
}

sub draw_status_line {
    $screen->at($row + 1, 0);
    my $status_line = sprintf " [%d/%d] %s",
        $offset + $select + 1, scalar @{$statuses->statuses}, $status_help;
    print YELLOW ON_BLUE
        $status_line, ' ' x ($col - length($status_line) + 1), RESET;
    $screen->at($row + 2, 0)->clreol();
}

sub command {
    my $prompt = ':';
    my $term = new Term::ReadLine::Gnu;
    if (defined ($_ = $term->readline($prompt))) {
        #TODO
    }
}

sub select_up {
    return if $select + $offset <= 0;
    if ($select == 0) {
        return scroll_up();
    } else {
        return --$select;
    }
}

sub select_down {
    return if $select + $offset >= $#{$statuses->statuses};
    if ($select == $row) {
        return scroll_down();
    } else {
        return ++$select;
    }
}

sub scroll_up {
    $offset--;
    return -1;
}

sub scroll_down {
    $offset++;
    return $row + 1;
}

sub insert_before {
    if ($#{$statuses->statuses} <= $row) {
        select_down();
    } else {
        $offset++;
    }
}

sub update {
    $statuses->update(
        sub {
            draw();
            draw_status_line();
            $screen->at($row + 2, 0)->clreol();
        }
    );
}

END {
    $screen->clrscr() if $screen;
}
