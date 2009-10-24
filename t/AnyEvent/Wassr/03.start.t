use Test::More tests => 8;
use Test::Exception;

use AnyEvent::Wassr;

my $class = 'AnyEvent::Wassr';
can_ok($class, qw/start/);

lives_ok {
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->start;
};

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_friends;
    $wassr->start;
    is($wassr->{schedule}{statuses_friends}{wait}, 0);
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_replies;
    $wassr->start;
    is($wassr->{schedule}{statuses_replies}{wait}, 0);
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_friends(2);
    $wassr->receive_statuses_replies(1);
    $wassr->start;
    is($wassr->{schedule}{statuses_friends}{wait}, 0);
    is($wassr->{schedule}{statuses_replies}{wait}, 1);
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_friends(1);
    $wassr->receive_statuses_replies(2);
    $wassr->start;
    is($wassr->{schedule}{statuses_friends}{wait}, 1);
    is($wassr->{schedule}{statuses_replies}{wait}, 0);
}
