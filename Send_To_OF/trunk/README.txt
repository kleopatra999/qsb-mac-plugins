# OmniFocus quick add for QSB

A Quick Search Box plugin that adds new tasks to OmniFocus

# DISCLAIMER

This plugin was not developed by the team at OmniGroup, and they should not be held responsible for any problems you have.

# INSTALL

1) Download the latest version from XXX
2) Drag the plugin to your QSB Plugins folder (~/Library/Application Support/Quick Search Box/Plugins)
3) Restart QSB

# USAGE

This plugin uses OmniFocus' email syntax to enter tasks.
The action will be parsed with the following delimiters:
 @ - specifies context
 :: or > - specifies project name
 $ - specifies a time estimate
 ! - after action sets flag
 // - specifies following text is note (probably works best as last entry)
 # - specifies date, one date is parsed as start date and two dates are parsed as start and due
 
 Invoke QSB, hit space to start text entry, enter task and tab to Send_To_OF
 
 i.e.  " call john @phone #today ::work // need to find out if http://url.com is still active"
 
 # UPDATES
 
 22Nov10 - Initial creation and commit
 
 # TODO
 
 Add Growl support
 
