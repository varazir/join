Syntax:

JOIN [-title "<text>"] [-deviceid <device id>] [-deviceids <device id>] [-deviceNames <text>] [-url <text>] [-clipboard] 
     [-priority <number>] [-tasker <text>][-smsnumber <number>] [-smstext] [-noencrypt] <text>

Description:

    To send messages using the JOIN API. NO encryption at the moment. 

Parameters:

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

    -clipboard:   Some text you want to set on the receiving device’s clipboard. If the device is an Android 
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
    
    
    Settings:
      Please /set join_api_token, the rest is used for encrypting /set join_email and /set join_encryption_password
                  
    Example:
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
