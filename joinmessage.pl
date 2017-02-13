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
use Mojo::UserAgent;

our $VERSION = '0.1'; 
our %IRSSI = (
    authors     => 'Varazir',
    contact     => 'Varazir',
    url         => "https://joaoapps.com/join/",
    name        => 'joinmessage',
    description => 'To send messages to join API https://joaoapps.com/join/',
    license     => 'GNU GPLv2 or later',
    changed     => "2017-02-12"
   );

sub cmd_help {
    my ($args) = @_;
    if ($args =~ /^join_msg *$/i) {
        print CLIENTCRAP <<HELP

Syntax:

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

    -deviceNames: a comma separated list of device names you want to send the push to. It can be parcial 
                  names. For example, if you set deviceNames to  Nexus,PC it’ll send it to devices called 
                  Nexus 5, Nexus 6, Home PC and Work PC if you have devices named that way. *Must be used with the API key to work!*

    -url:         A URL you want to open on the device. If a notification is created with this push, this 
                  will make clicking the notification open this URL.

    -clipboard:   Some <text> you want to set on the receiving device’s clipboard. If the device is an Android 
                  device and the Join accessibility service is enabled the text will be pasted right away in 
                  the app that’s currently opened.

    -priority:    Control how your notification is displayed: lower priority notifications are usually displayed 
                  lower in the notification list. Values from -2 (lowest priority) to 2 (highest priority). Default is 2.

    -smsnumber:   Phone number to send an SMS to. If you want to set an SMS you need to set this and the smstext values
                  %U%_OBS This is sent from your phone and will be charged according to that%_%U
    
    -smstext:     Some text to send in an SMS. If you want to set an SMS you need to set this and the smsnumber values

    -noencrypt    If you don't like to encrypt the message 
                  Encryption is still not working, please use this option at all time

    -tasker:      The command you use in a tasker profile (before the =:=)
    
    
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
        /JOIN_MSG -noencrypt -tasker irssi -text -deviceNames nexus I command my phone to lock.
      Set the clipboard on your computer or paste the text on your phone
        /JOIN_MSG -noencrypt -clipboard -deviceNames nexus This is text that will be typed in the activ windows on my phone
HELP
;
Irssi::signal_stop;
    }
}

sub join_msg {
  my ($data, $server, $item) = @_;    
  my ($join_args, $join_rest) = Irssi::command_parse_options('join_msg', $data);
  my $join_token  = Irssi::settings_get_str('join_api_token');
  my $join_command  = '';
  my $ua  = Mojo::UserAgent->new;
  # Check parameters
  
  ref $join_args or return;

  if (!@{$join_args}{qw[deviceId deviceIds deviceNames]}) {
    Irssi::print("You need use one of this deviceId, deviceIds or deviceNames");
  }

  if (@{$join_args}{qw[clipboard smstext text]} && !length $join_rest) { 
    Irssi::print "You need to specify a text";
  }
  
  if(exists $join_args->{smstext} && !$join_args->{smsnumber}) {  
    Irssi::print("You are missing SMStext or SMSnumber");
  }
  
  
  #if (exists $join_args->{text} || exists $join_args->{smstext} || exists $join_args->{clipboard} || exists $join_args->{url} && $join_rest) {
  #} else {
  #  cmd_help("join_msg");
  #  Irssi::print("You need a text, smstext or clipboard");
  #  return 0;
  #}
  
  #if ($join_args->{deviceId} || $join_args->{deviceIds} || $join_args->{deviceNames}) {
  #} else {
  #  cmd_help("join_msg");
  #  Irssi::print("You need a deviceId, deviceIds or deviceNames");
  #  return 0;
  #}
  
  #if ($join_args->{smsnumber} && exists $join_args->{smstext}) {
  #} elsif (exists $join_args->{text} or exists $join_args->{clipboard} or exists $join_args->{url} ) {
  #} else {
  #  cmd_help("join_msg");
  #  Irssi::print("You need to set both smsnumber and smstext");
  #  return 0;
  #}
  
  # Mandatory parameters 
  
  foreach my $item ("text", "smstext", "clipboard") {
    if (exists $join_args->{$item}) {
      my $join_text = uri_escape("$join_rest");
      if (exists $join_args->{tasker} && $item eq "text") {
        $join_text = join("=:=",$join_args->{tasker}, $join_text);
      }
      if (exists $join_args->{noencrypt}) {
      } else {
        $join_text = join_encrypted($join_text);
      }
      $join_command = join("", $join_command, "&$item=", $join_text);
      last;
    }
  }
  
  foreach my $device ("deviceId", "deviceIds", "deviceNames") {
    if (exists $join_args->{$device}) {
      $join_command = join("", $join_command, "&$device=", $join_args->{$device});
      last;
    }
  }

	# Optional parameters

  if ($join_args->{title}) {
    my $join_title = uri_escape($join_args->{title});
    if (exists $join_args->{noencrypt}) {
    } else {
      $join_title = join_encrypted($join_title);
    }
    $join_command = join("", $join_command, "&title=", $join_title);
  }

	if ($join_args->{url}) {
	  my $join_url = uri_escape($join_args->{url});
    if (exists $join_args->{noencrypt}) {
    } else {
      $join_url = join_encrypted($join_url);
    }
      $join_command = join("", $join_command, "&url=", $join_url);
	}
  
  if (exists $join_args->{priority}){
    my $join_priority = $join_args->{priority};
    $join_command = join("", $join_command, "&priority=", $join_priority);
    } else {
      my $join_priority = "2";
      $join_command = join("", $join_command, "&priority=", $join_priority);
    }
    
  if (exists $join_args->{smsnumber}){
    my $join_smsnumber = $join_args->{smsnumber};
    $join_command = join("", $join_command, "&smsnumber=", $join_smsnumber);
  }
   
  # Creating the final command

  $join_command = join("", "sendPush?apikey=", $join_token, $join_command);
  
  my $tx = $ua->get("https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/$join_command")->result;
  
  if (exists $join_args->{debug}) {
  	if (exists $join_args->{noencrypt}) {
      $join_command =~ s/%/%%/g; # For the print to be correct in IRSSI
    } 
    Irssi::print("https://joinjoaomgcd.appspot.com/_ah/api/messaging/v1/$join_command");
  }
}

sub join_encrypted {
     my ($text) = @_ ? shift : $_;
     my $encryption_password  = Irssi::settings_get_str('join_encryption_password');
     my $iterationcount = 5000;
     my $salt = Irssi::settings_get_str('join_email');
     my $key = Crypt::PBKDF2->new(iterations=>$iterationcount,output_len=>16)->PBKDF2($salt, $encryption_password);
     my $bytes = rand_chars(size => 16, set => 'all');
     my $cipher = Crypt::Mode::CBC->new('AES')->encrypt($text, $key, $bytes);
     my $encrypted = join("=:=",encode_b64($bytes), encode_b64($cipher));
 
     Irssi::print("encryption is not working at the moment, please add -noencrypt");
      
     return $encrypted;
 
}
     
# Settings

Irssi::settings_add_str('join', 'join_api_token', '');
Irssi::settings_add_str('join', 'join_encryption_password', '');
Irssi::settings_add_str('join', 'join_email', '');

# Commands
Irssi::command_bind_first('help' => 'cmd_help');
Irssi::command_bind ('join_msg', => 'join_msg');
Irssi::command_set_options('join_msg' => '+title +deviceId +deviceIds +deviceNames +url clipboard @smsnumber smstext priority noencrypt +tasker text debug');
