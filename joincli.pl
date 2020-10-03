#!/usr/bin/perl -w 
use strict;
use warnings;
use Hash::Util qw();
use Encode;
use MIME::Base64;
use Data::Random qw(rand_chars);
use Crypt::Mode::CBC;
use Crypt::PBKDF2;
use Crypt::Misc qw(encode_b64u encode_b64);
use URI::Escape qw(uri_escape);
use Mojo;
use Crypt::PRNG qw(random_bytes);
use Crypt::KeyDerivation qw(pbkdf2);
use List::Util qw(all any);

my $array = $ARGV[0];
@ARGV = split(';', $array);

my $password = $ARGV[0];
my $email = $ARGV[1];
my $text = $ARGV[2];
my $message = uri_escape(join_encrypted($text));

print STDOUT $message;

sub join_encrypted { 
     # my ($text) = @_ ? shift : $_; 
     my $encryption_password = $password; 
     my $salt = $email; 
     my $key = pbkdf2($encryption_password, $salt, 5000, "SHA1", 32); # 32bytes = 256bit AES key 
     my $bytes = random_bytes(16); 
     my $cipher = Crypt::Mode::CBC->new('AES')->encrypt($text, $key, $bytes);
     my $encrypted = join("=:=", encode_b64($bytes), encode_b64($cipher)); 
     return $encrypted; 
}