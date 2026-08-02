# tmux-settings

Working base for Jade's tmux + Ghostty terminal environment. **Most of the files being edited live outside this directory**, mostly in the home directory, and most of them are not under version control. Read the project memory (`project_tmux_workspace`, `tmux_ghostty_env`, `tmux_claude_restore`, `tmux_claude_usage_ccc`) before changing anything here — those are Claude Code project-memory files under `~/.claude/projects/`, not files in this repo.

`~/.tmux.conf` and `~/.config/ghostty/config` are not in this repo either, so `tmux_setup_history` remains their only change history.

## Where the real files are

| Path | Versioned? | What |
|---|---|---|
| `~/.tmux.conf` | no | tmux config; heavily commented — read the comments before editing, several settings encode measured findings |
| `~/.config/ghostty/config` | no | Ghostty as a tmux-only host; every native shortcut remapped to `text:\x01…` (tmux prefix) |
| `scripts/tmux-{ram,weekday,resurrect-rewrite}.sh` | **yes** (this repo) | moved out of `~/.claude/hooks/` on 2026-08-02; symlinked back into it |
| `~/Workspaces/scripts/shell/*.sh` | **yes** (git) | `update-claude-usage.sh`, `tmux-claude-usage.sh`, `tmux-claude-window-status.sh`, `tmux-merge-window.sh`, `claude-code-change.sh` — also symlinked into `~/.claude/hooks/` |
| `~/Library/LaunchAgents/` | no | `com.jadewon.claude-usage.plist` (60 s), `me.jadewon.ccc-maintain.plist` (10 min) |

Every tmux helper script is *called* as `~/.claude/hooks/<name>.sh` (that is what `~/.tmux.conf` references) but is *stored* elsewhere and symlinked in. New tmux scripts go into `scripts/` here; never write a real file directly into `~/.claude/hooks/`.

## Applying and verifying a change

```
~/.tmux.conf            → prefix + r  (bind r source-file, shows a confirmation)
~/.config/ghostty/config → restart Ghostty (no reload keybind is configured)
LaunchAgent plist        → launchctl unload + load; check its log before claiming it runs
```

Status-bar work is verified by reading the cache/log, not by asking the user what they see:

```
/tmp/claude-usage-cache.txt        usage string the status bar renders (pre-coloured tmux tags)
~/.local/state/tmux-resurrect-rewrite.log   pane → sessionId rewriting on every resurrect save
~/.claude/ccc-maintain.log         account backup / inactive-token refresh
```

## Rules for this directory

- **Log every change** to the `tmux_setup_history` memory file, dated. It is the only history `~/.tmux.conf` and the Ghostty config have.
- **Never lower `status-interval`** back toward 1 — see the comment at that line; it was raised to 15 after measuring 425 process spawns/sec.
- **Never apply a colour, icon or glyph choice unilaterally.** Print candidates with `echo`/ANSI so they can be compared in the user's own font, then let the user pick. Only offer glyphs whose rendering you verified.
- Anything touching credentials must run under launchd, not cron — cron has no access to the macOS GUI Keychain.
