package AnyEvent::Wassr;

use base 'Object::Event';
use Carp 'croak';

sub new {
   my $class = shift;
   my $self  = $class->SUPER::new(
       @_,
   );

   if (!defined($self->{username})) {
       croak "no 'username' given to AnyEvent::Wassr\n";
   }
   if (!defined($self->{password})) {
       croak "no 'password' given to AnyEvent::Wassr\n";
   }

   return $self;
}

1;
