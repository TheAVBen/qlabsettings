# QLab Settings

A macOS AppleScript that toggles the recommended show settings from [QLab's guide](https://qlab.app/docs/v5/general/preparing-your-mac/) on (Show Mode) and off (Restore).

## What it changes

- **Spotlight indexing** — `mdutil -ai off` / `on`
- **Sleep** — `pmset` sets `displaysleep`, `disksleep`, and `sleep` to `0`; Restore returns the defaults of 10, 10, and 30 minutes
- **Screen saver** — `idleTime` of `0` / `1200` seconds
- **Automatic Time Machine** — `tmutil disable` / `enable`
- **Displays have separate Spaces** (optional, for video) — `com.apple.spaces` `spans-displays`; needs a log out

## Do by hand

Not scripted: Software Update, Do Not Disturb / Focus, iCloud, and Photos.

## Install as an app

In Script Editor, choose **File > Export** and set **File Format** to **Application**.

Or:

```bash
osacompile -o "/Applications/QLab Prep.app" QLab-Show-Prep.applescript && codesign --force --deep -s - "/Applications/QLab Prep.app"
```

## Permissions

Grant the app (not Terminal) Full Disk Access in **System Settings > Privacy & Security > Full Disk Access**. `tmutil` needs this. Relaunch the app after granting it. Re-exporting may need the toggle switched off and on. The script asks for an admin password each run.

## Usage

Run the app, pick **Show Mode** or **Restore**, and choose whether to change Spaces. Wait for the final dialog before logging out. The script never logs out or restarts itself.

## Customising

Restore values are properties at the top of the script.

This project is not affiliated with Figure 53.
