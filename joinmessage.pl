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
use Crypt::Misc qw(encode_b64u encode_b64); 
use URI::Escape qw(uri_escape);
use Mojo;
use Crypt::PRNG qw(random_bytes);  
use Crypt::KeyDerivation qw(pbkdf2); 
use List::Util qw(all any);

our $VERSION = '0.5'; 
our %IRSSI = (
    authors     => 'Varazir',
    contact     => 'Varazir',
    url         => "https://joaoapps.com/join/",
    name        => 'joinmessage',
    description => 'To send messages to join API https://joaoapps.com/join/',
    license     => 'GNU GPLv2 or later',
    changed     => "2017-02-17"
   );
   
   # Note Thanks for the help from http://search.cpan.org/~mik/ and Botje in #perl at Freenode 
   
sub cmd_help {
    my ($args) = @_;
    if ($args =~ /^join_msg *$/i) {
        print CLIENTCRAP <<HELP

%U%_Syntax:%_%U

JOIN [-title "<text>"] [-deviceid <device id>] [-deviceids <device id>] [-deviceNames <text>] [-url <text>] [-clipboard] 
     [-priority <number>] [-tasker <text>][-smsnumber <number>] [-smstext] [-noencrypt] <text>


%U%_Description:%_%U

    To send messages using the JOIN API. NO encryption at the moment. 


%U%_Parameters:%_%U

    -title:       If used, will always create a notification on the receiving device with this as the 
                  title and text as the notification’s text. %U%_It NEED to be ""%_%U 
    
    <text>        Text pushed to the device

    -deviceid:    The device ID or group ID (must use API Key for groups) of the device you want to 
                  send the message to. It is mandatory that you either set this or the deviceIds parameter.

    -deviceids:   A comma separated list of device IDs you want to send the push to. It is mandatory 
                  that you either set this or the deviceId parameter.

    -devicenames: a comma separated list of device names you want to send the push to. It can be parcial 
                  names. For example, if you set deviceNames to  Nexus,PC it’ll send it to devices called 
                  Nexus 5, Nexus 6, Home PC and Work PC if you have devices named that way. *Must be used with the API key to work!*

    -url:         A URL you want to open on the device. If a notification is created with this push, this 
                  will make clicking the notification open this URL.

    -clipboard:   Some <text> you want to set on the receiving device’s clipboard. If the device is an Android 
                  device and the Join accessibility service is enabled the text will be pasted right away in 
                  the app that’s currently opened.

    -priority:    Control how your notification is displayed: lower priority notifications are usually displayed 
                  lower in the notification list. Values from -2 (lowest priority) to 2 (highest priority). Default is 2.
                  Negative value need to ""

    -smsnumber:   Phone number to send an SMS to. If you want to set an SMS you need to set this and the smstext values
                  %U%_OBS This is sent from your phone and will be charged according to that%_%U
    
    -smstext:     Some text to send in an SMS. If you want to set an SMS you need to set this and the smsnumber values

    -noencrypt    If you don't like to encrypt the message 
                  Encryption is still not working, please use this option at all time

    -tasker:      The command you use in a tasker profile (before the =:=)
    
    -all:         Send the message to all your devices. Only works with -deviceNames and -deviceids
    
    
    %U%_Settings:%_%U
    
      Please /set join_api_token, the rest is used for encrypting /set join_email and /set join_encryption_password
                  

    %U%_Example:%_%U
    
      Send text to your device(s) called nexus*
        /JOIN_MSG -noencrypt -title "To my Phone" -text -deviceNames nexus Hello Phone! How are you today?
      Send a url to your home computer
        /JOIN_MSG -noencrypt -url https://google.com -deviceNames home
      Send SMS over your phone 
        /JOIN_MSG -noencrypt -smsnumber 5554247 -smstext Hello, the sms was sent from IRC
      Send command to tasker, a tasker profile listening to in this 'irssi=:=' need to be setup on your phone for this to work.
        /JOIN_MSG -noencrypt -tasker irssi -text -deviceNames nexus I command my phone to do something.
      Set the clipboard on your computer or paste the text on your phone.
        /JOIN_MSG -noencrypt -clipboard -deviceNames nexus This is text that will be typed in the activ windows on my phone
      Send clipboard to all your devices
        /JOIN_MSG -noencrypt -deviceNames -all -clipboard This is my clipboard
HELP
;
     Irssi::signal_stop;
    }
  if ($args =~ /^join_list *$/i) {
        print CLIENTCRAP <<HELP
        
%U%_Syntax:%_%U

JOIN_LIST [-deviceName] [-id]


%U%_Description:%_%U

    List your JOIN Devices  


%U%_Parameters:%_%U

    -deviceName   Default value and do not need to be set if you don't want both name and ID. 
      
    -deviceId     If you like to get the deviceId and not the names
    

%U%_Example:%_%U

   

HELP
;
     Irssi::signal_stop;
  }  
}

sub join_list {
  my ($data, $server, $item) = @_;
  my ($args, $rest) = Irssi::command_parse_options('join_list', $data);
  my $ua  = Mojo::UserAgent->new;
  my $join_token  = Irssi::settings_get_str('join_api_token');
  my $device_list = $ua->get("https://joinjoaomgcd.appspot.com/_ah/api/registration/v1/listDevices?apikey=$join_token")->result->json;
  my $device_array = $device_list->{records};
  my $devicenames = '';
  my $deviceids = '';
  
  for my $devices (@{$device_array}) {
    my $devicename = ${$devices}{'deviceName'};
    my $deviceid = ${$devices}{'deviceId'};
    ($devicename) = split(/\s+/, $devicename);
    $devicenames = join(", ", $devicename, $devicenames);
    $deviceids = join(", ", $deviceid, $deviceids);
  }
  if (!$data) {
    Irssi::print("Your deviceName's are $devicenames");
  } elsif (exists $args->{deviceID}) {
     Irssi::print("Your deviceName's are $devicenames");
     Irssi::print("Your deviceID's are $deviceids");
  } elsif ($data eq "deviceIds" || exists $args->{deviceID}) {
     $deviceids =~ s/ //g;
     return $deviceids;
  } elsif ($data eq "deviceNames" || exists $args->{deviceName}) {
     $devicenames =~ s/ //g;
     return $devicenames;
  }
}

sub join_msg {
  my ($data, $server, $item) = @_;    
  my ($join_args, $join_rest) = Irssi::command_parse_options('join_msg', $data);
  my $join_token  = Irssi::settings_get_str('join_api_token');
  my $join_command  = '';
  my $join_text;
  my $ua  = Mojo::UserAgent->new;
  # Check parameters

  ref $join_args or return 0;

  if(exists $join_args->{debug}) { 
    use Data::Dumper;
    print "join_args";
    print Dumper($join_args);
    print "join_rest";
    print Dumper($join_rest);
  }

  if (all { !exists $join_args->{$_} or !length $join_args->{$_}} qw[deviceId deviceIds deviceNames]) {
    if (!exists $join_args->{all}) {
     Irssi::print("You need to use one of this -deviceId, -deviceIds or -deviceNames and a value" );
     return 0;
    }
  }

  if (all { !exists $join_args->{$_}} qw[clipboard smstext text url ]) {
    Irssi::print("You need to use one of this -clipboard, -smstext, -text or -url" );
    return 0;
  }

  if (any { exists $join_args->{$_} } qw[clipboard smstext text] and !length $join_rest) {
    Irssi::print("You need to specify a text");
    return 0;
   }

  if (exists $join_args->{url} and !length $join_args->{url}) {
    Irssi::print("You need specify a url");
    return 0;
  }
  
  if(exists $join_args->{smstext} && !$join_args->{smsnumber}) {  
     Irssi::print("You are missing SMSnumber");
     return 0;
  } elsif ($join_args->{smsnumber} && !exists $join_args->{smstext}) {
     Irssi::print("You are missing SMStext");
     return 0;
  }
  
#  if (!exists $join_args->{noencrypt} && $VERSION < 1 && !length $join_args->{noencrypt}){
#    Irssi::print("encryption is not working at the moment, please add -noencrypt");
#    return 0;
#  }
  
  # Mandatory parameters 
  
  foreach my $item ("text", "smstext", "clipboard") {
    if (exists $join_args->{$item}) {
      my $join_text;
      if ($join_args->{tasker} && $item eq "text") {
        $join_rest = join("=:=",$join_args->{tasker}, $join_rest);
      }
      if (!exists $join_args->{noencrypt}) {
        $join_text = uri_escape(join_encrypted($join_rest));
      } else {
          $join_text = uri_escape("$join_rest");
      }
      $join_command = join("", $join_command, "&$item=", $join_text);
      last;
    }
  }
  
  my $join_device;
  
  foreach my $device ("deviceId", "deviceIds", "deviceNames") {
    if (exists $join_args->{$device}) {
      if (exists $join_args->{all} && $device ne "deviceId") {
        my $device_list = join_list("$device");
        $join_command = join("", $join_command, "&$device=", $device_list);
        $join_device = $device_list;
      } else {
          $join_command = join("", $join_command, "&$device=", $join_args->{$device});
          $join_device = $join_args->{$device};
          last;
      }
    }
  }

	# Optional parameters

  if ($join_args->{title}) {
    my $join_title  = $join_args->{title};
    if (exists $join_args->{noencrypt}) {
      $join_title = uri_escape($join_title);
    } else {
        $join_title = uri_escape(join_encrypted($join_title));
    }
    $join_command = join("", $join_command, "&title=", $join_title);
  }

    if ($join_args->{url}) {
      my $join_url;
      if (exists $join_args->{noencrypt}) {
        $join_url =  uri_escape($join_args->{url});
      } else {
          $join_url = uri_escape(join_encrypted($join_args->{url}));
      }
      $join_command = join("", $join_command, "&url=", $join_url);
    }
  
  if ($join_args->{priority}){
    my $join_priority = uri_escape($join_args->{priority});
    $join_command = join("", $join_command, "&priority=", $join_priority);
    } else {
      my $join_priority = "2";
      $join_command = join("", $join_command, "&priority=", $join_priority);
    }
    
  if ($join_args->{smsnumber}){
    my $join_smsnumber = $join_args->{smsnumber};
    $join_command = join("", $join_command, "&smsnumber=", $join_smsnumber);
  }
   
  # Creating the final command

  $join_command = join("", "sendPush?apikey=", $join_token, $join_command);
  
  if (exists $join_args->{debug}) {
    if (exists $join_args->{noencrypt}) {
     $join_command =~ s/%/%%/g; # For the print to be correct in IRSSI
    } 
    Irssi::print("https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/$join_command");
    } else {
      my $tx = $ua->get("https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/$join_command")->result->json;
      if ($tx->{success} eq "true") {
      Irssi::print("Message sent successfully to $join_device");
      $join_command =~ s/%/%%/g;
      Irssi::print("https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/$join_command");
      } else {
        Irssi::print($tx->{errorMessage});
      }
    }
  }

sub join_encrypted { 
     my ($text) = @_ ? shift : $_; 
     my $encryption_password = Irssi::settings_get_str('join_encryption_password'); 
     my $salt = Irssi::settings_get_str('join_email'); 
     my $key = pbkdf2($encryption_password, $salt, 5000, "SHA1", 32); # 32bytes = 256bit AES key 
     my $bytes = random_bytes(16); 
     my $cipher = Crypt::Mode::CBC->new('AES')->encrypt($text, $key, $bytes);
     # my $cipher = Crypt::Mode::CBC->new('AES')->encrypt(encode("UTF-8", $text), $key, $bytes);
     my $encrypted = join("=:=", encode_b64($bytes), encode_b64($cipher)); 
     return $encrypted; 
}



sub join_encrypted_old {
     my ($text) = @_ ? shift : $_;
     my $encryption_password  = Irssi::settings_get_str('join_encryption_password');
     my $iterationcount = 5000;
     my $salt = Irssi::settings_get_str('join_email');
     my $key = Crypt::PBKDF2->new(iterations=>$iterationcount,output_len=>16)->PBKDF2($salt, $encryption_password);
     my $bytes = rand_chars(size => 16, set => 'all');
     my $cipher = Crypt::Mode::CBC->new('AES')->encrypt($text, $key, $bytes);
     my $encrypted = join("=:=",encode_b64u($bytes), encode_b64u($cipher));
 
     return $encrypted;
}
     
# Settings

Irssi::settings_add_str('join', 'join_api_token', '');
Irssi::settings_add_str('join', 'join_encryption_password', '');
Irssi::settings_add_str('join', 'join_email', '');

# Commands
Irssi::command_bind_first('help' => 'cmd_help');
Irssi::command_bind ('join_msg', => 'join_msg');
Irssi::command_bind ('join_list', => 'join_list');
Irssi::command_set_options('join_msg' => '+title -deviceId -deviceIds -deviceNames +url clipboard +smsnumber smstext +priority -noencrypt +tasker text debug all');
Irssi::command_set_options('join_list' => 'id deviceName deviceId');
