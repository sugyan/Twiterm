package Twiterm;

use Date::Parse 'str2time';
use Encode qw/decode_utf8 encode_utf8/;
use Log::Message;
use Proc::InvokeEditor;
use Term::ANSIColor ':constants';
use Term::Screen;
use Twiterm::PageState;
use Twiterm::Statuses;
use Unicode::EastAsianWidth;

my $log = new Log::Message(
    tag => __PACKAGE__,
);

sub new {
    my $class = shift;

    my $self = {
        consumer_key    => 'Apfmu9l9LnyUoNFteXPw9Q',
        consumer_secret => 'O9Qq2a82X0gRXQTrAzplf65v5Tr2EEVGbf13Ew3IA',
    };

    return bless $self, $class;
}

sub run {
    my ($self, $config) = @_;
    $log->store('run');

    $self->{config} = $config;
    $self->{statuses} = new Twiterm::Statuses(
        twitter_params => {
            consumer_key        => $self->{consumer_key},
            consumer_secret     => $self->{consumer_secret},
            access_token        => $self->{config}->{access_token},
            access_token_secret => $self->{config}->{access_token_secret},
            username            => $self->{config}->{username},
            password            => $self->{config}->{password},
        },
        statuses_params => {
            delegate  => $self,
            update_cb => \&_update_done,
        },
    );
    $self->{page} = new Twiterm::PageState();
    $self->{page}->addPage({
        name     => 'log',
        timeline => 'log',
    });
    for my $page_config (@{$self->{config}->{pages}}) {
        $self->{page}->addPage($page_config);
    }
    $self->{timeline} = [];
    $self->{screen} = new Term::Screen;
    $self->{row} = $self->{screen}->rows() - 2;
    $self->{col} = $self->{screen}->cols() - 1;

    $self->{statuses}->start();
    $self->_update_done();
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
        $self->_favorite()    if $char eq 'f';
        $self->_change_mode() if $char =~ /\x0A|\x20/;
        $self->_update() if $char eq 'u';
    }
    $self->{screen}->clrscr();
}

sub _draw {
    my $self = shift;

    if ($self->{page}->disp_mode()) {
        $self->_draw_detail(@_);
    } else {
        $self->_draw_list(@_);
    }

    $self->{screen}->at(0, 0);
    my $timeline_size = scalar @{$self->{timeline}};
    my $status_line = sprintf " [ %d / %d ] - %s", (
        $timeline_size ? $self->{page}->position + 1 : 0,
        $timeline_size,
        $self->{page}->name,
    );
    print YELLOW ON_BLUE
        $status_line, ' ' x ($self->{col} - 1 - length $status_line), RESET;
}

sub _draw_detail {
    my $self = shift;

    $self->{screen}->at(1, 0)->clreos();
    my $status = $self->{timeline}->[$self->{page}->position()];
    my $user   = $self->{statuses}->user($status->{user_id});

    return if !defined $status;
    {
        local $\ = "\r\n";
        my $time_and_client = sprintf "%s - from %s",
            (scalar localtime $status->{created_at}, $status->{source});
        my $user_name = sprintf "%s / %s",
            ($status->{screen_name}, encode_utf8 $user->{name});
        $user_name = "(protected) $user_name" if ($user->{protected});
        my $friends_and_followers = sprintf "%d friends, %d followers",
                ($user->{friends_count}, $user->{followers_count});
        print $time_and_client;
        print $user_name;
        print encode_utf8 $status->{text};
        if (my $reply_user = $status->{in_reply_to_screen_name}) {
            my $reply_status =
                $self->{statuses}->status($status->{in_reply_to_status_id});
            print '';
            print "in reply to \@$reply_user:";
            print encode_utf8 $reply_status->{text} if $reply_status;
        }
        print '';
        print '';
        print '';
        print $friends_and_followers;
        print encode_utf8 $user->{location} || '';
        print $user->{url} || '';
        print encode_utf8 $user->{description} || '';
    }
}

sub _draw_list {
    my $self = shift;
    my @range = @_;

    if (@range == 1) {
        if ($range[0] == 0) {
            $self->{screen}->at(1, 0)->il();
            push @range, 1;
        }
        if ($range[0] > 0) {
            $self->{screen}->at(1, 0)->dl();
            unshift @range, $self->{row} - 1;
        }
    }
    @range = (0 .. $self->{row}) if @range == 0;

    for my $line (@range) {
        my $text;
        my $status = $self->{timeline}->[$line + $self->{page}->offset];
        if (defined $status) {
            $text = $status->{line};
            if (!defined $text) {
                # ターミナル幅に合わせて1行以内に収まるように切る
                my @created_at = localtime $status->{created_at};
                my $status_text = sprintf ' %02d/%02d %02d:%02d:%02d - %s : ', (
                    $created_at[4] + 1,
                    @created_at[3, 2, 1, 0],
                    $status->{screen_name},
                );
                my $width = length $status_text;
                for my $char (split //, $status->{text}) {
                    $width += $char =~ /\p{InFullwidth}/ ? 2 : 1;
                    last if $width > $self->{col};
                    $status_text .= $char;
                }
                $text = encode_utf8 $status_text;
                $status->{line} = $text;
            }
            substr($text, 0, 1, $status->{favorited} ? '*' : ' ');
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

    if ($self->{page}->select == 0) {
        $self->{page}->decr_offset;
        $self->_draw(0);
    } else {
        my $line = $self->{page}->decr_select;
        $self->_draw($line - 1, $line);
    }
}

sub _select_next {
    my $self = shift;
    return if $self->{page}->position >= $#{$self->{timeline}};

    if ($self->{page}->select == $self->{row}) {
        $self->{page}->incr_offset;
        $self->_draw($self->{row});
    } else {
        my $line = $self->{page}->incr_select;
        $self->_draw($line, $line + 1);
    }
}

sub _change_mode {
    my $self = shift;
    $self->{page}->change_mode();
    $self->_draw();
}

sub _update_done {
    my $self = shift;
    $self->{timeline} = $self->_get_statuses();
    $self->_draw();
}

sub _get_statuses {
    my $self = shift;
    my $timeline = $self->{page}->timeline();
    if ($timeline eq 'log') {
        return [map {
            created_at  => str2time($_->when),
            screen_name => $_->tag,
            text        => $_->message,
        }, reverse $log->retrieve()];
    }
    if ($timeline eq 'friends') {
        return [$self->{statuses}->friends()];
    }
    if ($timeline eq 'mentions') {
        return [$self->{statuses}->mentions()];
    }
    return [];
}

sub _update {
    my $self = shift;
    my $status = Proc::InvokeEditor->edit;
    $log->store('request update...');
    $self->{statuses}->update(decode_utf8($status));
}

sub _favorite {
    my $self = shift;
    my $status = $self->{timeline}->[$self->{page}->position()];
    $log->store('request favorite...');
    $self->{statuses}->favorite($status->{id});
}

1;
