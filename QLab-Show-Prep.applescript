-- QLab Show Prep / Restore
-- Based on https://qlab.app/docs/v5/general/preparing-your-mac/
-- Show Mode switches off Spotlight indexing, sleep, Power Nap, the screen saver and
-- automatic Time Machine backups, and optionally "Displays have separate Spaces".
-- The settings in place beforehand are saved, and Restore puts those back.

-- Used by Restore only when Show Mode hasn't saved the previous settings.
property fallbackDisplaySleep : 10 -- minutes
property fallbackDiskSleep : 10 -- minutes
property fallbackSystemSleep : 30 -- minutes
property fallbackScreenSaver : 1200 -- seconds (20 min)

property dialogTitle : "QLab Prep"

on run
	set stateDir to (POSIX path of (path to application support from user domain)) & "QLab Prep"
	set savedAt to do shell script "cat " & quoted form of (stateDir & "/saved-at.txt") & " 2>/dev/null || true"
	set hasState to savedAt is not ""
	
	if hasState then
		set restoreText to "Restore: put back the settings saved on " & savedAt & "."
	else
		set restoreText to "Restore: no saved settings found, so standard defaults are used."
	end if
	set modeChoice to button returned of (display dialog "QLab Mac settings" & return & return & "Show Mode: switch off Spotlight indexing, sleep, Power Nap, screen saver and automatic Time Machine backups." & return & return & restoreText buttons {"Cancel", "Restore", "Show Mode"} default button "Show Mode" cancel button "Cancel" with title dialogTitle with icon note)
	set isShow to modeChoice is "Show Mode"
	
	set changeSpaces to askAboutSpaces(isShow)
	set spacesArg to "no"
	if changeSpaces then set spacesArg to "yes"
	
	set createdState to false
	set adminDone to false
	try
		if isShow then
			-- Keep the first snapshot if Show Mode is run twice, so Restore never "restores" show settings.
			if not hasState then
				do shell script shellCommand(captureSh(), {stateDir})
				set createdState to true
			end if
			set adminOut to do shell script shellCommand(showAdminSh(), {stateDir}) with administrator privileges
			set adminDone to true
			set userOut to do shell script shellCommand(showUserSh(), {stateDir, spacesArg})
		else
			set adminOut to do shell script shellCommand(restoreAdminSh(), {stateDir, fallbackDisplaySleep, fallbackDiskSleep, fallbackSystemSleep}) with administrator privileges
			set adminDone to true
			set userOut to do shell script shellCommand(restoreUserSh(), {stateDir, spacesArg, fallbackScreenSaver})
		end if
	on error errMsg number errNum
		if createdState and not adminDone then do shell script "rm -rf " & quoted form of stateDir
		if errNum is -128 then return
		display dialog "Something went wrong:" & return & errMsg buttons {"OK"} default button "OK" with title dialogTitle with icon stop
		return
	end try
	
	set parsed to parseResults(adminOut & return & userOut)
	set okText to item 1 of parsed
	set failText to item 2 of parsed
	set timeMachineFailed to item 3 of parsed
	
	if not isShow and failText is "" then do shell script "rm -rf " & quoted form of stateDir
	
	set parts to {}
	if okText is not "" then set end of parts to "Done:" & return & okText
	if failText is not "" then set end of parts to "Not done:" & return & failText
	if timeMachineFailed then set end of parts to "For Time Machine, give this app Full Disk Access (System Settings > Privacy & Security > Full Disk Access) and run it again, or set backups to Manual in Time Machine settings."
	if isShow and hasState then set end of parts to "Your settings from before Show Mode were already saved on " & savedAt & " and have been kept for Restore."
	if not isShow and not hasState then set end of parts to "No saved settings were found, so the standard defaults at the top of the script were used."
	if not isShow and hasState and failText is not "" then set end of parts to "Your saved settings have been kept so you can run Restore again."
	if changeSpaces then set end of parts to "Log out and back in for the Spaces change to take effect."
	if isShow then set end of parts to "Still do by hand: Software Update, Do Not Disturb / Focus, iCloud." & return & "On a laptop, closing the lid still puts the Mac to sleep."
	
	set summary to joinList(parts, return & return)
	if failText is "" then
		display dialog summary buttons {"OK"} default button "OK" with title dialogTitle with icon note
	else
		display dialog summary buttons {"OK"} default button "OK" with title dialogTitle with icon caution
	end if
end run

on askAboutSpaces(isShow)
	set spansNow to (do shell script "defaults read com.apple.spaces spans-displays 2>/dev/null || echo 0") is "1"
	if isShow and not spansNow then
		set question to "Turn OFF \"Displays have separate Spaces\"?" & return & return & "Only matters if QLab sends video to more than one display. Takes effect after you log out and back in."
		set yesButton to "Turn Off"
	else if not isShow and spansNow then
		set question to "Turn \"Displays have separate Spaces\" back ON?" & return & return & "This is the macOS default. Takes effect after you log out and back in."
		set yesButton to "Turn On"
	else
		return false
	end if
	return (button returned of (display dialog question buttons {"Cancel", "Skip", yesButton} default button "Skip" cancel button "Cancel" with title dialogTitle)) is yesButton
end askAboutSpaces

-- Each script prints one line per step: OK|label, SKIP|label or FAIL|label|detail.
on parseResults(outputText)
	set okLines to {}
	set failLines to {}
	set timeMachineFailed to false
	repeat with p in paragraphs of outputText
		set lineText to contents of p
		if lineText starts with "OK|" then
			set end of okLines to "- " & text 4 thru -1 of lineText
		else if lineText starts with "SKIP|" then
			set end of okLines to "- " & text 6 thru -1 of lineText
		else if lineText starts with "FAIL|" then
			set detail to text 6 thru -1 of lineText
			if detail contains "Time Machine" then set timeMachineFailed to true
			set end of failLines to "- " & replaceText(detail, "|", ": ")
		end if
	end repeat
	return {joinList(okLines, return), joinList(failLines, return), timeMachineFailed}
end parseResults

on shellCommand(scriptText, args)
	-- Script Editor may save the multi-line strings below with CR line endings, which sh rejects.
	set scriptText to replaceText(shellPrelude() & linefeed & scriptText, return, linefeed)
	set cmd to "/bin/sh -c " & quoted form of scriptText & " qlabprep"
	repeat with a in args
		set cmd to cmd & " " & quoted form of ((contents of a) as text)
	end repeat
	return cmd
end shellCommand

on shellPrelude()
	return "r() { L=$1; shift; if O=$(\"$@\" 2>&1); then echo \"OK|$L\"; else echo \"FAIL|$L|$(echo \"$O\" | tr -s '[:space:]' ' ')\"; fi; }
idx() { mdutil -as 2>/dev/null | awk '/^[^[:space:]].*:$/ { v = substr($0, 1, length($0) - 1); next } /Indexing enabled/ && v != \"\" { print v; v = \"\" }'; }"
end shellPrelude

-- $1 state dir
on captureSh()
	return "mkdir -p \"$1\" && cd \"$1\" || exit 1
pmset -g custom | awk '/^Battery Power:/ { f = \"-b\" } /^AC Power:/ { f = \"-c\" } /^UPS Power:/ { f = \"-u\" } f != \"\" && ($1 == \"displaysleep\" || $1 == \"disksleep\" || $1 == \"sleep\" || $1 == \"powernap\") { a[f] = a[f] \" \" $1 \" \" $2 } END { for (k in a) print k a[k] }' > pmset.txt
idx > spotlight.txt
defaults -currentHost read com.apple.screensaver idleTime > screensaver.txt 2>/dev/null || echo unset > screensaver.txt
date '+%d %b %Y at %H:%M' > saved-at.txt"
end captureSh

-- $1 state dir (runs as root)
on showAdminSh()
	return "cd \"$1\" || exit 1
if [ ! -f timemachine.txt ]; then
defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup > timemachine.txt 2>/dev/null || echo unknown > timemachine.txt
fi
mdutil -a -i off > /dev/null 2>&1
ON=$(idx)
if [ -z \"$ON\" ]; then echo 'OK|Spotlight indexing off'; else echo \"FAIL|Spotlight indexing off|Still on for: $(echo \"$ON\" | paste -s -d , -)\"; fi
r 'Sleep off' pmset -a displaysleep 0 disksleep 0 sleep 0
if pmset -g custom | grep -q powernap; then r 'Power Nap off' pmset -a powernap 0; fi
r 'Automatic Time Machine backups off' tmutil disable
exit 0"
end showAdminSh

-- $1 state dir, $2 change Spaces (yes/no)
on showUserSh()
	return "r 'Screen saver off' defaults -currentHost write com.apple.screensaver idleTime -int 0
if [ \"$2\" = yes ]; then r 'Displays have separate Spaces off' defaults write com.apple.spaces spans-displays -bool true; fi
exit 0"
end showUserSh

-- $1 state dir, $2 $3 $4 fallback display, disk and system sleep (runs as root)
on restoreAdminSh()
	return "if cd \"$1\" 2>/dev/null && [ -f saved-at.txt ]; then SAVED=1; else SAVED=0; fi
if [ $SAVED = 1 ] && [ -f spotlight.txt ]; then
BAD=
while IFS= read -r v; do
[ -d \"$v\" ] || continue
mdutil -i on \"$v\" > /dev/null 2>&1
mdutil -s \"$v\" 2>/dev/null | grep -q 'Indexing enabled' || BAD=\"$BAD, $v\"
done < spotlight.txt
if [ -z \"$BAD\" ]; then echo 'OK|Spotlight indexing restored'; else echo \"FAIL|Spotlight indexing restored|Still off for: ${BAD#, }\"; fi
else
mdutil -a -i on > /dev/null 2>&1
if [ -n \"$(idx)\" ]; then echo 'OK|Spotlight indexing on'; else echo 'FAIL|Spotlight indexing on|No volume reports indexing enabled'; fi
fi
if [ $SAVED = 1 ] && [ -s pmset.txt ]; then
BAD=
while IFS= read -r a; do
[ -n \"$a\" ] || continue
O=$(pmset $a 2>&1) || BAD=\"$BAD $O\"
done < pmset.txt
if [ -z \"$BAD\" ]; then echo 'OK|Sleep and Power Nap restored'; else echo \"FAIL|Sleep and Power Nap restored|$(echo $BAD)\"; fi
else
r 'Sleep set to standard defaults' pmset -a displaysleep \"$2\" disksleep \"$3\" sleep \"$4\"
fi
TM=unknown
if [ $SAVED = 1 ] && [ -f timemachine.txt ]; then TM=$(cat timemachine.txt); fi
if [ \"$TM\" = 0 ]; then echo 'SKIP|Automatic Time Machine backups left off, as they were before Show Mode'; else r 'Automatic Time Machine backups on' tmutil enable; fi
exit 0"
end restoreAdminSh

-- $1 state dir, $2 change Spaces (yes/no), $3 fallback screen saver seconds
on restoreUserSh()
	return "SS=
if [ -f \"$1/saved-at.txt\" ]; then SS=$(cat \"$1/screensaver.txt\" 2>/dev/null); fi
case $SS in
'') r 'Screen saver set to standard default' defaults -currentHost write com.apple.screensaver idleTime -int \"$3\" ;;
unset) defaults -currentHost delete com.apple.screensaver idleTime 2>/dev/null; echo 'OK|Screen saver restored' ;;
*) r 'Screen saver restored' defaults -currentHost write com.apple.screensaver idleTime -int \"$SS\" ;;
esac
if [ \"$2\" = yes ]; then r 'Displays have separate Spaces on' defaults write com.apple.spaces spans-displays -bool false; fi
exit 0"
end restoreUserSh

on replaceText(theText, findText, replaceWith)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to findText
	set textParts to text items of theText
	set AppleScript's text item delimiters to replaceWith
	set theText to textParts as text
	set AppleScript's text item delimiters to oldDelims
	return theText
end replaceText

on joinList(theList, delim)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delim
	set joined to theList as text
	set AppleScript's text item delimiters to oldDelims
	return joined
end joinList
