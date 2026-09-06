# PomodoroCat

A tiny, cute, always-on-top cat that lives on your desktop and runs Pomodoro focus sessions. Click it to start/pause, right-click (or the gear icon) for settings. Finished focus sessions are logged to a note in your Obsidian vault and saved locally.

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

- **Double-click** the cat: start / pause the current session. (Single-click does nothing, so nudging the cat while dragging it won't accidentally pause it.)
- **Click the "(task)" text** under the countdown while the timer is idle and type what the session is for. Press Return (or click away) to save it. It's only shown while idle — starting a session hides it and restores the full-size countdown — and it clears itself after each completed focus session so you describe the next one fresh.
- **Right-click the cat, or click the small gear icon** in its corner: open Settings.
- **Drag** the cat anywhere on screen; its position is remembered across relaunches.
- A ring appears around the cat while focusing, showing time remaining.
- The cat's ears/tail/mood change between focusing, break, and idle, with a little celebration bounce when a session finishes.
- **Click the 🐱 icon in the menu bar** to hide the cat (e.g. before screen sharing) or show it again, and to quit the app entirely. The timer keeps running in the background while hidden.

## Obsidian logging

Every completed **focus** session (not breaks) is appended to a note in your vault as a line under that day's heading:

```markdown
## 09/06/2026

- 14:32 — 25 min — Write Q3 report
- 15:05 — 25 min — Review PR #142
```

The day heading (`mm/dd/yyyy`) is created automatically when the day's first session lands. Sessions with no task typed just log the time and duration.

The note defaults to `PomodoroLog.md` in the vault Obsidian last had open, detected from Obsidian's own config. Change it in Settings — type a path or use "Choose…". If the note doesn't exist yet it's created; the day heading and time come from when the session *started*, so a session running past midnight files under the day it began.

Obsidian picks up the change on its own — nothing needs to be running, and a failed write never interrupts the timer. The session is still recorded locally either way.

## Local history

Every completed session (focus and breaks) is appended to:

```
~/Library/Application Support/PomodoroCat/history.json
```

as one JSON object per line (JSONL), including the session's task (if any) and whether it was successfully written to the Obsidian note.

## Settings

- Duration presets — **Classic** (25 min focus / 1 min break), **Medium** (50 / 5), **Long** (90 / 10) — or fully custom minutes for focus and break. Focus and break sessions simply alternate; there are no long breaks.
- Changes apply starting with the *next* session — an in-progress countdown is never interrupted.
- The Obsidian note to log sessions to.
- "Launch at login" toggle.
- "Reset Timer" returns to idle immediately.

## Development

```
make debug   # runs the raw debug binary directly (no bundle) — fastest inner loop,
             # but notifications need the packaged .app to work correctly
make clean   # removes build artifacts and the .app bundle
```

Project layout:

```
Sources/PomodoroCat/
  App/            entry point, app delegate, floating panel + click handling
  Timer/          timer state machine and session configuration
  Cat/            the procedurally-drawn cat view and its moods
  Settings/       settings window/view, UserDefaults storage
  Notifications/  local notification handling
  Obsidian/       appending sessions to the vault note
  History/        local JSONL session history
```
