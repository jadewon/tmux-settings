# tmux-settings

Helper scripts for a tmux + [Ghostty](https://ghostty.org) + [Claude Code](https://claude.com/claude-code) setup on macOS: two status-bar readouts and a `tmux-resurrect` hook that brings every pane back on its original Claude Code conversation after a reboot.

This repo holds the scripts only. `~/.tmux.conf` and `~/.config/ghostty/config` are not included.

## Scripts

| Script | Wired into | What it does |
|---|---|---|
| `scripts/tmux-ram.sh` | `status-right` | Prints `<A>%/<B>%` — A is memory used by the Activity Monitor definition (active + wired + compressor), B is the wider definition the `tmux-cpu` plugin uses (also counts inactive/speculative, minus purgeable and file-backed). Colour comes from memory *pressure*, not the percentages: red above 1 GiB swap or 10 GiB compressed, yellow above any swap or 5 GiB compressed, green otherwise. |
| `scripts/tmux-weekday.sh` | `status-right` | Prints the weekday as a kanji character `月火水木金土日`, one colour per day. |
| `scripts/tmux-resurrect-rewrite.sh` | `@resurrect-hook-post-save-all` | After every resurrect save, walks each pane → pane PID → child `claude` PID → sessionId (read from `~/.claude/sessions/<PID>.json`) and rewrites the saved command line to `claude --dangerously-skip-permissions --resume <uuid>` (see the note below about that flag). sessionIds never change, so a `/rename`d session still restores correctly — a name-based resume would not. The save file is only overwritten if the rewritten copy has exactly as many lines as the original. Logs to `~/.local/state/tmux-resurrect-rewrite.log`. |

## Requirements

- macOS — `tmux-ram.sh` reads `vm_stat` / `sysctl vm.swapusage`, so it is not portable to Linux
- tmux 3.x
- `jq` at `/usr/bin/jq` (shipped with recent macOS; otherwise edit the `JQ=` line)
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) — for `tmux-resurrect-rewrite.sh` only
- A font with CJK coverage — for `tmux-weekday.sh` only

## Install

Clone anywhere and point `~/.tmux.conf` at the scripts:

```tmux
set -g status-right "… RAM:#(/path/to/tmux-settings/scripts/tmux-ram.sh) | %H:%M:%S #(/path/to/tmux-settings/scripts/tmux-weekday.sh)"

set -g @resurrect-processes '"~claude->claude *"'
set -g @resurrect-hook-post-save-all '/path/to/tmux-settings/scripts/tmux-resurrect-rewrite.sh'
```

Then `prefix + r` (or `tmux source-file ~/.tmux.conf`).

Status-bar scripts are re-run on every redraw, so keep `status-interval` high — at `1` this setup measured 425 process spawns/sec against 196/sec at `15`.

## Note on `tmux-resurrect-rewrite.sh`

The rewritten command line hardcodes `claude --dangerously-skip-permissions --resume <uuid>`, which is this author's preference. Drop that flag from the script if you do not want restored panes to skip permission prompts.
