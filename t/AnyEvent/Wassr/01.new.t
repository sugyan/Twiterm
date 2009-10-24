use Test::More tests => 5;
use Test::Exception;

use AnyEvent::Wassr;

my $class = 'AnyEvent::Wassr';

throws_ok { $class->new() } qr/$class/;

throws_ok {
    $class->new(
        username => 'username',
    );
} qr/no 'password'/;

throws_ok {
    $class->new(
        password => 'password',
    );
} qr/no 'username'/;

my $obj = new_ok($class => [
    username => 'username',
    password => 'password',
]);

isa_ok($obj, 'Object::Event');
