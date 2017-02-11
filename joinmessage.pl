use strict;
use warnings;
use Irssi;
use Irssi::TextUI;
use Hash::Util qw();
use Encode; 
use MIME::Base64; 
use Data::Random qw(rand_chars); 
use Crypt::Mode::CBC; 
use Crypt::PBKDF2; 
use Crypt::Misc qw(encode_b64); 
use URI::Escape qw(uri_escape); 

our $VERSION = '0.1'; 
our %IRSSI = (
    authors     => 'Varazir',
    contact     => 'Varazir',
    url         => "https://joaoapps.com/join/",
    name        => 'joinmessage',
    description => 'To send messages to join API https://joaoapps.com/join/',
    license     => 'GNU GPLv2 or later',
   );

my $wget_Cmd = "wget --tries=2 --timeout=10 --no-check-certificate -qO- /dev/null";
my $join_Command = '';

sub cmd_help {
    my ($args) = @_;
    if ($args =~ /^join_msg_new *$/i) {
        print CLIENTCRAP <<HELP

Syntax:

JOIN [-title <text>] [-deviceid <device id>] [-deviceids <device id>] [-deviceNames <text>] [-url <text>] [-clipboard <text>] 
     [-priority <number>] [-smsnumber <number>] [-smstext <text>] [-encrypt] <text>

Description:

    To send messages using the JOIN API. NO encryption at the moment

Parameters:

    -title:       If used, will always create a notification on the receiving device with this as the 
                  title and text as the notification’s text
    
    <text>        Text pushed to the device

    -deviceid:    The device ID or group ID (must use API Key for groups) of the device you want to 
                  send the message to. It is mandatory that you either set this or the deviceIds parameter.

    -deviceids:   A comma separated list of device IDs you want to send the push to. It is mandatory 
                  that you either set this or the deviceId parameter.

    -deviceNames: a comma separated list of device names you want to send the push to. It can be parcial 
                  names. For example, if you set deviceNames to  Nexus,PC it’ll send it to devices called 
                  Nexus 5, Nexus 6, Home PC and Work PC if you have devices named that way. *Must be used with the API key to work!*

    -url:         A URL you want to open on the device. If a notification is created with this push, this 
                  will make clicking the notification open this URL.

    -clipboard:   Some text you want to set on the receiving device’s clipboard. If the device is an Android 
                  device and the Join accessibility service is enabled the text will be pasted right away in 
                  the app that’s currently opened.

    -priority:    Control how your notification is displayed: lower priority notifications are usually displayed 
                  lower in the notification list. Values from -2 (lowest priority) to 2 (highest priority). Default is 2.

    -smsnumber:   Phone number to send an SMS to. If you want to set an SMS you need to set this and the smstext values

    -smstext:     Some text to send in an SMS. If you want to set an SMS you need to set this and the smsnumber values
    
    -encrypt      If you like to encrypt the message
HELP
;
Irssi::signal_stop;
    }
}

sub join_msg_new {
    my ($data, $server, $item) = @_;    
    my ($join_args, $join_rest) = Irssi::command_parse_options('join_msg_new', $data);
    my $join_token  = Irssi::settings_get_str('join_api_token');
    
	if ($join_args->{url}){
	   my $join_url = uri_escape "$join_args->{url}";
       if ($join_args->{encrypt}) {
          $join_url = join_ecrypted($join_url);
       }
       $join_Command = join("", $join_Command, "&url=", $join_url);

    } elsif ($join_rest) {
       my $join_text = uri_escape "$join_rest";
       if ($join_args->{encrypt}) {
          $join_text = join_ecrypted($join_rest);
       }
       $join_Command = join("", $join_Command, "&text=", "$join_text");
    } else {
       Irssi::print("You need a text or a url");
    }
    
    if ($join_args->{deviceId}){
        my $join_deviceid  = $join_args->{deviceId};
        $join_Command = join("", $join_Command, "&deviceId=", $join_deviceid);
        
     } elsif ($join_args->{deviceIds}) {
        my $join_deviceids = $join_args->{deviceIds};
        $join_Command = join("", $join_Command, "&deviceIds=", $join_deviceids);
        
     } elsif ($join_args->{deviceNames}) {
        my $join_devicenames = $join_args->{deviceNames};
        $join_Command = join("", $join_Command, "&deviceNames=", $join_devicenames);
        
     } else {
        Irssi::print("You need deviceId, deviceIds or deviceNames");
     }


    if ($join_args->{title}) {
        my $join_title = $join_args->{title};
        if ($join_args->{encrypt}) {
          $join_title = join_ecrypted($join_title);
        }
        $join_Command = join("", $join_Command, "&title=", $join_title);
    }

    $join_Command = join("", "sendPush?apikey=", $join_token, $join_Command);

	$join_Command =~ s/%/%%/g; # For printing the correct in IRSSI 
	
    Irssi::print("joinjoaomgcd.appspot.com/_ah/api/messaging/v1/$join_Command");
	
	$join_Command  = '';
	
}

sub join_encrypt {
     my ($text) = @_ ? shift : $_;
     my $encryption_password  = Irssi::settings_get_str('join_encryption_password');
     my $iterationcount = 5000;
     my $salt = Irssi::settings_get_str('join_email');
     my $key = Crypt::PBKDF2->new(iterations=>$iterationcount,output_len=>16)->PBKDF2($salt, $encryption_password);
     my $bytes = rand_chars(size => 16, set => 'all');
     my $cipher = Crypt::Mode::CBC->new('AES')->encrypt($text, $key, $bytes);
     my $encrypted = join("=:=",encode_b64($bytes), encode_b64($cipher));
 
 return $encrypted;
 
}
     
#    $join_Url =~ s/%/%%/g;   USED for displaying the url correct in irssi 

# Settings

Irssi::settings_add_str('join', 'join_api_token', '');
Irssi::settings_add_str('join', 'join_encryption_password', '');
Irssi::settings_add_str('join', 'join_email', '');

# Commands
Irssi::command_bind_first('help' => 'cmd_help');
Irssi::command_bind ('join_msg_new', => 'join_msg_new');
Irssi::command_set_options('join_msg_new' => '-title -deviceId -deviceIds -deviceNames -url -clipboard -smsnumber -smstext -priority encrypto');

# my $wget = `$wget_Cmd "https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/sendPush$join_Command"`;
# undef $join_Command
