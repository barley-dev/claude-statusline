# Claude Code Statusline

> A colorful, informative status bar for Claude Code — context usage, cost tracking, Git status, and rate limits at a glance.

Inspired by [YAHA 學堂](https://www.youtube.com/@yaboruei)'s video: [Claude Code 最該裝的不是 Skill，是這個腳本](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-)

## Preview

```
[Opus] my-project (main +2 ~3)
████░░░░░░ 45% │ $1.87 · 12m0s
5h: 35% (reset 2h 15m) │ 7d: 62% (reset 3d 5h)
```

**Line 1:** Model name, folder, Git branch with staged/modified counts

**Line 2:** Color-coded context progress bar (green < 70%, yellow 70-90%, red > 90%), session cost, elapsed time

**Line 3:** 5-hour and 7-day rate limit usage with reset countdown (Pro/Max users only)

## Quick Install

```bash
git clone https://github.com/barley-dev/claude-statusline.git
cd claude-statusline
./install.sh
```

That's it. Restart Claude Code and you'll see the statusline at the bottom.

## What the Installer Does

1. Checks that `jq` is installed (required dependency)
2. Writes `statusline.sh` to `~/.claude/statusline.sh`
3. Safely merges `statusLine` config into `~/.claude/settings.json`
   - Creates backup (`settings.json.bak`) before modifying
   - Won't overwrite existing config — only adds/updates `statusLine`
   - Asks before replacing an existing statusline setup
   - Refuses to touch malformed JSON files

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
| Context progress bar | 10-block bar, auto-colors by usage level |
| Model name | Shows current model (Opus, Sonnet, etc.) |
| Git status | Branch name, staged (+N) and modified (~N) file counts |
| Session cost | Running total in USD |
| Elapsed time | Minutes and seconds since session start |
| Rate limits | 5-hour and 7-day usage with countdown to reset |
| Adaptive | Works with any model/context window size |
| Safe install | Backs up settings, validates JSON, never overwrites blindly |

## Running Tests

```bash
# Statusline functionality tests (33 tests)
./test_statusline.sh

# Installer tests (22 tests)
./test_installer.sh
```

## How It Works

Claude Code pipes session data as JSON to your statusline script via stdin on every response. The script parses it with `jq`, formats the output with ANSI colors, and prints it. Claude Code displays the output at the bottom of the terminal. No API tokens consumed — runs locally.

## Acknowledgments

This project is based on the tutorial by [YAHA 學堂](https://www.youtube.com/@yaboruei). Their [video](https://youtu.be/wHRFuTqlpD8?si=-iWSGmMA3w7z40V-) walks through the concepts of Claude Code statusline scripting. We built on their approach with additional features (rate limits, safe installer, TDD test suite) and fixed the `seq 1 0` macOS compatibility bug.

## License

MIT
