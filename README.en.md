# Claude Code Statusline

**v1.1.0** · A colorful, informative status bar for Claude Code — context usage, cost tracking, Git status, and rate limits at a glance.

[繁體中文](README.md)

Inspired by [YAHA 學堂](https://www.youtube.com/@yaboruei)'s video: [Claude Code 最該裝的不是 Skill，是這個腳本](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-)

## Preview

```
[Opus] my-project (main +2 ~3)
████░░░░░░ Ctx 45% │ $1.87 · 12m0s
5h: 35% (reset 2h 15m) │ 7d: 62% (reset 3d 5h)
```

| Line | Content |
|---|---|
| Line 1 | Model name, folder, Git branch (staged/modified counts) |
| Line 2 | Color-coded context progress bar (green <70%, yellow 70-90%, red >90%), `Ctx` percentage, session cost, elapsed time |
| Line 3 | 5-hour / 7-day rate limit usage with reset countdown (Pro/Max only) |

## Installation

### Plugin Install (Recommended)

```bash
# Run inside Claude Code
/plugin marketplace add barley-dev/claude-statusline
```

### Traditional Install

```bash
git clone https://github.com/barley-dev/claude-statusline.git
cd claude-statusline
./install.sh
```

Restart Claude Code and the statusline appears at the bottom.

## What the Installer Does

1. Checks that `jq` is installed (required dependency)
2. Writes `statusline.sh` to `~/.claude/statusline.sh`
3. Safely merges `statusLine` config into `~/.claude/settings.json`
   - Creates backup (`settings.json.bak`) before modifying
   - Won't overwrite existing config — only adds/updates `statusLine`
   - Asks before replacing an existing statusline setup
   - Refuses to touch malformed JSON files

## `/statusline` Command

After installation, type `/statusline` inside Claude Code to open the interactive configuration menu:

```
Claude Code Statusline Settings

Current status:
  Line 1 (Model/Folder/Git): Visible
  Line 2 (Progress bar/Cost/Time): Visible
  Line 3 (Rate Limits): Visible

Choose an action:
  1. Toggle Line 1
  2. Toggle Line 2
  3. Toggle Line 3
  4. Exit
```

Toggle each line's visibility through conversation — no manual config file editing needed.

## Per-Line Toggle

v1.1.0 supports independent control over each line's visibility:

| Line | How to toggle |
|---|---|
| Line 1 | Via `/statusline` menu, or edit `~/.claude/statusline_config.json` directly |
| Line 2 | Same as above |
| Line 3 | Same as above (Rate Limit line — Free users may prefer to hide it) |

## Uninstall

```bash
./uninstall.sh
```

Removes `statusline.sh` and the `statusLine` key from `settings.json`. All other settings are preserved.

## Requirements

- [Claude Code](https://claude.com/claude-code)
- [jq](https://jqlang.github.io/jq/) — JSON processor
  - macOS: `brew install jq`
  - Ubuntu: `sudo apt install jq`

## Features

| Feature | Description |
|---|---|
| Context progress bar | 10-block bar, auto-colors by usage level, prefixed with `Ctx` |
| Model name | Shows current model (Opus, Sonnet, etc.) |
| Git status | Branch name, staged (+N) and modified (~N) file counts |
| Session cost | Running total in USD |
| Elapsed time | Minutes and seconds since session start |
| Rate limits | 5-hour and 7-day usage with countdown to reset |
| Adaptive | Works with any model / context window size (200K / 1M) |
| Safe install | Backs up settings, validates JSON, never overwrites blindly |
| Plugin install | One-command install via `/plugin marketplace` (v1.1.0) |
| Interactive config | `/statusline` conversational menu for configuration (v1.1.0) |
| Per-line toggle | Independently show/hide each of the 3 lines (v1.1.0) |

## Running Tests

```bash
# Statusline functionality tests (33 tests)
./test_statusline.sh

# Installer tests (22 tests)
./test_installer.sh
```

## How It Works

Claude Code pipes session data as JSON to your statusline script via stdin on every response. The script parses it with `jq`, formats the output with ANSI colors, and prints it. Claude Code displays the output at the bottom of the terminal. Runs locally — no API tokens consumed.

## Acknowledgments

This project is based on the tutorial by [YAHA 學堂](https://www.youtube.com/@yaboruei). Their [video](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-) walks through the concepts of Claude Code statusline scripting. We built on their approach with additional features and fixed the `seq 1 0` macOS compatibility bug:

- Real-time rate limits display (5h / 7d usage + reset countdown)
- Safe install/uninstall scripts (backup, JSON validation, merge without overwrite)
- Full TDD test suite (55 tests)
- Fixed macOS `seq 1 0` bug causing incorrect progress bar at 0% and 100%
- Plugin format installation support (v1.1.0)
- `/statusline` interactive configuration menu (v1.1.0)
- Per-line visibility toggle (v1.1.0)

## License

MIT
