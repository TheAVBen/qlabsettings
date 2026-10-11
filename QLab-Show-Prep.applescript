-- QLab Show Prep / Restore
-- Based on https://qlab.app/docs/v5/general/preparing-your-mac/
-- Covers: Spotlight indexing, sleep, screen saver, Time Machine,
-- and (optionally) "Displays have separate Spaces" for video.

property restoreDisplaySleep : 10 -- minutes
property restoreDiskSleep : 10 -- minutes
property restoreSystemSleep : 30 -- minutes
property restoreScreenSaver : 1200 -- seconds (20 min)

set modeChoice to button returned of (display dialog "QLab Mac settings" & return & return & "Show Mode: switch off Spotlight indexing, sleep, screen saver and automatic Time Machine." & return & return & "Restore: put them back to normal." buttons {"Cancel", "Restore", "Show Mode"} default button "Show Mode" cancel button "Cancel" with title "QLab Prep" with icon note)

set spacesChoice to button returned of (display dialog "Also change \"Displays have separate Spaces\"? (Only matters for video. Needs a log out to take effect.)" buttons {"Skip", "Yes"} default button "Skip" with title "QLab Prep")

if modeChoice is "Show Mode" then
	set adminCmd to "mdutil -ai off; pmset -a displaysleep 0 disksleep 0 sleep 0"
	set tmCmd to "tmutil disable"
	set userCmd to "defaults -currentHost write com.apple.screensaver idleTime -int 0"
	if spacesChoice is "Yes" then set userCmd to userCmd & "; defaults write com.apple.spaces spans-displays -bool TRUE"
	set doneMsg to "Show Mode settings applied."
else
	set adminCmd to "mdutil -ai on; pmset -a displaysleep " & restoreDisplaySleep & " disksleep " & restoreDiskSleep & " sleep " & restoreSystemSleep & ""
	set tmCmd to "tmutil enable"
	set userCmd to "defaults -currentHost write com.apple.screensaver idleTime -int " & restoreScreenSaver
	if spacesChoice is "Yes" then set userCmd to userCmd & "; defaults write com.apple.spaces spans-displays -bool FALSE"
	set doneMsg to "Normal settings restored."
end if

try
	do shell script adminCmd with administrator privileges
	do shell script userCmd & "; killall cfprefsd"
on error errMsg
	display dialog "Something went wrong:" & return & errMsg buttons {"OK"} default button "OK" with title "QLab Prep" with icon stop
	return
end try

try
	do shell script tmCmd with administrator privileges
on error
	set doneMsg to doneMsg & return & return & "Time Machine was NOT changed: give this app Full Disk Access (System Settings > Privacy & Security), or set backups to Manual in Time Machine settings."
end try

if spacesChoice is "Yes" then set doneMsg to doneMsg & return & return & "Log out and back in for the Spaces change to take effect."
display dialog doneMsg & return & return & "Still do by hand: Software Update, Do Not Disturb, iCloud." buttons {"OK"} default button "OK" with title "QLab Prep"
