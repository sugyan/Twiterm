package Twiterm;

use Mouse;

has 'config' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

no Mouse;

__PACKAGE__->meta->make_immutable;

use Encode 'encode_utf8';
use Term::ANSIColor ':constants';
use Term::Screen;
use Twiterm::PageState;
use Twiterm::Statuses;
use Unicode::EastAsianWidth;


sub BUILD {
    my $self = shift;

    $self->{statuses} = new Twiterm::Statuses(
        username => $self->{config}->{username},
        password => $self->{config}->{password},
        delegate => $self,
        update_cb => \&_update_done,
    );
    $self->{page} = new Twiterm::PageState();
    $self->{page}->addPage({
        timeline => 'log',
    });
    for my $page_config (@{$self->{config}->{pages}}) {
        $self->{page}->addPage($page_config);
    }
    $self->{timeline} = [];

    $self->{screen} = new Term::Screen;
    $self->{row} = $self->{screen}->rows() - 2;
    $self->{col} = $self->{screen}->cols() - 1;
}

sub DESTROY {
    my $self = shift;
}

sub run {
    my $self = shift;

    $self->_draw();
    while (1) {
        my $cv = AnyEvent->condvar;
        my $io; $io = AnyEvent->io(
            fh   => \*STDIN,
            poll => 'r',
            cb   => sub {
                my $char = $self->{screen}->noecho()->getch();
                $cv->send($char);
            },
        );
        # キー入力待ち
        my $char = $cv->recv;

        last if $char eq 'q';
        $self->_page_prev()   if $char eq 'h';
        $self->_select_next() if $char eq 'j';
        $self->_select_prev() if $char eq 'k';
        $self->_page_next()   if $char eq 'l';
        $self->_update_done() if $char eq 'd';
    }
    $self->{screen}->clrscr();
}

sub _draw {
    my $self = shift;

    if ($self->{page}->{disp_mode}) {
        $self->_draw_detail(@_);
    } else {
        $self->_draw_list(@_);
    }

    $self->{screen}->at(0, 0);
    my $timeline_size = scalar @{$self->{timeline}};
    my $status_line = sprintf " [ %d / %d ] ",
        $timeline_size ? $self->{page}->position + 1 : 0, $timeline_size;
    print YELLOW ON_BLUE
        $status_line, ' ' x ($self->{col} - length($status_line) - 1), RESET;
}

sub _draw_list {
    my $self = shift;
    my $target = shift;

    my @range = (0 .. $self->{row});
    if (defined $target) {
        if ($target == -1) {
            $self->{screen}->at(1, 0)->il();
            $target++;
        }
        if ($target == $self->{row} + 1) {
            $self->{screen}->at(1, 0)->dl();
            $target--;
        }
        @range = ($target - 1, $target, $target + 1);
        shift @range if $target == 0;
        pop   @range if $target == $self->{row};
    }
    for my $line (@range) {
        my $text;
        my $status = $self->{timeline}->[$line + $self->{page}->offset];
        if (defined $status) {
            $text = $status->{line};
            if (!defined $text) {
                # ターミナル幅に合わせて1行以内に収まるように切る
                my @created_at = localtime $status->{created_at};
                my $status_text = sprintf '%02d/%02d %02d:%02d:%02d - %s : ',
                    $created_at[4] + 1, @created_at[3, 2, 1, 0], $status->{user}->{screen_name};
                my $width = length $status_text;
                for my $char (split //, $status->{text}) {
                    $width += $char =~ /\p{InFullwidth}/ ? 2 : 1;
                    last if $width > $self->{col};
                    $status_text .= $char;
                }
                $text = encode_utf8 $status_text;
                $status->{line} = $text;
            }
        }
        $self->{screen}->at($line + 1, 0);
        $self->{screen}->reverse() if ($self->{page}->select == $line);
        $self->{screen}->puts($text)->clreol()->normal();
    }
}

sub _page_prev {
    my $self = shift;
    $self->{page}->prev();
    $self->{timeline} = $self->_get_statuses();
    $self->_draw();
}

sub _page_next {
    my $self = shift;
    $self->{page}->next();
    $self->{timeline} = $self->_get_statuses();
    $self->_draw();
}

sub _select_prev {
    my $self = shift;
    return if $self->{page}->position <= 0;

    my $line;
    if ($self->{page}->select == 0) {
        $self->{page}->decr_offset;
        $line = -1;
    } else {
        $line = $self->{page}->decr_select;
    }
    $self->_draw($line);
}

sub _select_next {
    my $self = shift;
    return if $self->{page}->position >= $#{$self->{timeline}};

    my $line;
    if ($self->{page}->select == $self->{row}) {
        $self->{page}->incr_offset;
        $line = $self->{row} + 1;
    } else {
        $line = $self->{page}->incr_select;
    }
    $self->_draw($line);
}

sub _update_done {
    my $self = shift;
    $self->{timeline} = $self->_get_statuses();
}

sub _get_statuses {
    my $self = shift;
    my $timeline = $self->{page}->timeline();
    if ($timeline eq 'friends') {
        return $self->{statuses}->friends;
    }
    if ($timeline eq 'mentions') {
        return $self->{statuses}->mentions;
    }
    return [];
}

1;
