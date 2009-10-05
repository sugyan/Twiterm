use strict;
use warnings;

use AnyEvent;
use Encode 'encode_utf8';
use File::Basename 'dirname';
use Getopt::Long;
use Term::ANSIColor ':constants';
use Term::Screen;
use Term::ReadLine;
use Unicode::EastAsianWidth;

use FindBin '$Bin';
use lib "$Bin/lib";
use Twiterm;

my $usage = "usage: perl $0 --username=<username> --password=<password>\n";
my ($username, $password);
GetOptions(
    'username=s' => \$username,
    'password=s' => \$password,
) or die;
warn $usage and die if (!defined($username) or !defined($password));
my $twiterm = new Twiterm(
    config => {
        username => $username,
        password => $password,
        pages => [ {
            timeline => 'friends',
        }, {
            timeline => 'mentions',
        } ],
    },
);
$twiterm->run();

exit;
my $statuses = new Statuses(
    username => $username,
    password => $password,
    update_cb => \&draw,
);

my $screen = new Term::Screen;
my $status_help = '(h)<-prev (j)down (k)up (l)->next (:)command (q)quit';
my ($row, $col) = ($screen->rows() - 3, $screen->cols() - 1);
my @pages = (
    new Page( timeline => sub { $statuses->friends;  } ),
    new Page( timeline => sub { $statuses->mentions; } ),
);
my $page = 0;

$screen->clrscr();
draw_status_line();

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
    }
    if ($char eq 'k') {
        my $line = select_up();
        next if !defined $line;
        draw($line);
    }
    if ($char eq 'h') {
        $page--;
        $page += @pages if $page < 0;
        draw();
    }
    if ($char eq 'l') {
        $page++;
        $page = 0 if $page > $#pages;
        draw();
    }
    if ($char =~ /(\x0A|\x0D|\x20)/) {
        $pages[$page]->{disp_mode} = !$pages[$page]->{disp_mode};
        draw();
    }
    update() if $char eq 'd';
    if ($char eq ':') {
        # ReadLineの前に一度$screenをundefにする
        undef $screen;
        command();
        $screen = new Term::Screen;
        draw();
    }
    last if $char eq 'q';
}

sub draw_detail {
    $screen->clrscr();

    my $status = &{$pages[$page]->timeline}->[$pages[$page]->position()];
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
#     return unless @{&{$pages[$page]->timeline}};

    if ($pages[$page]->{disp_mode}) { draw_detail(@_); } else {
        draw_list(@_); } draw_status_line(); }

sub draw_list {
    my $target = shift;

    my @range = (0 .. $row);
    # $targetが指定されていればその前後のみを描画
    if (defined $target) {
        if ($target == -1) {
            $screen->at(0, 0)->il();
            $target++;
        }
        if ($target == $row + 1) {
            $screen->at(0, 0)->dl();
            $target--;
        }
        @range = ($target - 1, $target, $target + 1);
        shift @range if $target == 0;
        pop   @range if $target == $row;
    }
    # 各行の描画
    for my $line (@range) {
        my $status = &{$pages[$page]->timeline}->[$line + $pages[$page]->{offset}];
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
        $screen->reverse() if ($pages[$page]->{select} == $line);
        $screen->puts($text)->clreol()->normal();
    }
    $screen->at($row + 2, 0)->clreol();
}

sub draw_status_line {
    $screen->at($row + 1, 0);
    my $status_line = sprintf " [%d/%d] %s",
        $pages[$page]->position() + 1, scalar @{&{$pages[$page]->timeline}}, $status_help;
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
    return if $pages[$page]->position() <= 0;
    if ($pages[$page]->{select} == 0) {
        return scroll_up();
    } else {
        return --$pages[$page]->{select};
    }
}

sub select_down {
    return if $pages[$page]->position() >= $#{&{$pages[$page]->timeline}};
    if ($pages[$page]->{select} == $row) {
        return scroll_down();
    } else {
        return ++$pages[$page]->{select};
    }
}

sub scroll_up {
    $pages[$page]->{offset}--;
    return -1;
}

sub scroll_down {
    $pages[$page]->{offset}++;
    return $row + 1;
}

# END {
#     $screen->clrscr() if $screen;
# }
