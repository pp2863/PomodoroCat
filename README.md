# PomodoroCat

A tiny, cute, always-on-top cat that lives on your desktop and runs Pomodoro focus sessions. Click it to start/pause, right-click (or the gear icon) for settings. Finished focus sessions post to a Discord channel of your choice and are saved locally.

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install` if you don't have them). Full Xcode is **not** required.

## Build & run

```
make build   # builds PomodoroCat.app in this folder
make run     # builds (if needed) and opens the app
```

First launch: since the app is ad-hoc signed (not notarized), macOS will block a plain double-click. Either:
- Right-click `PomodoroCat.app` → Open → Open, or
- System Settings → Privacy & Security → scroll down → "Open Anyway"

After the first approval it launches normally. There's no Dock icon — the floating cat is the main UI, plus a small 🐱 menu bar icon for hiding it and quitting.

## Using it

- **Left-click** the cat: start / pause the current session.
- **Right-click the cat, or click the small gear icon** in its corner: open Settings.
- **Drag** the cat anywhere on screen; its position is remembered across relaunches.
- A ring appears around the cat while focusing, showing time remaining.
- The cat's ears/tail/mood change between focusing, break, and idle, with a little celebration bounce when a session finishes.
- **Click the 🐱 icon in the menu bar** to hide the cat (e.g. before screen sharing) or show it again, and to quit the app entirely. The timer keeps running in the background while hidden.

## Discord logging

1. In Discord: **Server Settings → Integrations → Webhooks → New Webhook**. Pick the channel you want your focus log posted to, and copy the Webhook URL.
2. Open PomodoroCat's Settings (right-click the cat) and paste the URL into "Webhook URL."
3. Click "Test Webhook" to confirm it works.
4. From then on, every completed **focus** session (not breaks) posts a message there.

If a post fails (e.g. no internet), the app retries once, then gives up silently — it never blocks or crashes the UI. The session is still recorded locally either way.

## Local history

Every completed session (focus and breaks) is appended to:

```
~/Library/Application Support/PomodoroCat/history.json
```

as one JSON object per line (JSONL), including whether it was successfully posted to Discord.

## Settings

- Duration presets (Classic 25/5, Long 50/10) or fully custom minutes for focus / short break / long break, plus how many focus sessions happen before a long break.
- Changes apply starting with the *next* session — an in-progress countdown is never interrupted.
- "Launch at login" toggle.
- "Reset Timer" returns to idle immediately.

## Development

```
make debug   # runs the raw debug binary directly (no bundle) — fastest inner loop,
             # but notifications/Keychain need the packaged .app to work correctly
make clean   # removes build artifacts and the .app bundle
```

Project layout:

```
Sources/PomodoroCat/
  App/            entry point, app delegate, floating panel + click handling
  Timer/          timer state machine and session configuration
  Cat/            the procedurally-drawn cat view and its moods
  Settings/       settings window/view, UserDefaults + Keychain storage
  Notifications/  local notification handling
  Discord/        webhook POST logic
  History/        local JSONL session history
```
