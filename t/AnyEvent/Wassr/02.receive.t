use Test::More tests => 16;

use AnyEvent::Wassr;

my $class = 'AnyEvent::Wassr';
can_ok($class, qw/receive_statuses_friends receive_statuses_replies/);

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    ok(!exists $wassr->{schedule});
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_friends;
    ok( exists $wassr->{schedule}{statuses_friends});
    ok(!exists $wassr->{schedule}{statuses_replies});
    is($wassr->{schedule}{statuses_friends}{weight}, 1);
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_replies;
    ok(!exists $wassr->{schedule}{statuses_friends});
    ok( exists $wassr->{schedule}{statuses_replies});
    is($wassr->{schedule}{statuses_replies}{weight}, 1);
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_friends;
    $wassr->receive_statuses_replies;
    ok(exists $wassr->{schedule}{statuses_friends});
    ok(exists $wassr->{schedule}{statuses_replies});
    is($wassr->{schedule}{statuses_friends}{weight}, 1);
    is($wassr->{schedule}{statuses_replies}{weight}, 1);
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_friends(3);
    $wassr->receive_statuses_replies(2);
    is($wassr->{schedule}{statuses_friends}{weight}, 3);
    is($wassr->{schedule}{statuses_replies}{weight}, 2);
}

{
    my $wassr = $class->new(
        username => 'username',
        password => 'password',
    );
    $wassr->receive_statuses_friends(2);
    $wassr->receive_statuses_replies(3);
    is($wassr->{schedule}{statuses_friends}{weight}, 2);
    is($wassr->{schedule}{statuses_replies}{weight}, 3);
}
