#!/usr/bin/perl
use strict;
use warnings;

use Net::Twitter::Lite;

my $nt = Net::Twitter::Lite->new(
    consumer_key    => 'Apfmu9l9LnyUoNFteXPw9Q',
    consumer_secret => 'O9Qq2a82X0gRXQTrAzplf65v5Tr2EEVGbf13Ew3IA',
);
# The client is not yet authorized: Do it now
print "Authorize this app at ", $nt->get_authorization_url, "\n";
print "and enter the PIN# :";

my $pin = <STDIN>; # wait for input
chomp $pin;

my($access_token, $access_token_secret) = $nt->request_access_token(verifier => $pin);
print "access_token: $access_token\n";
print "access_token_secret: $access_token_secret\n";
