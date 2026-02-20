# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A custom Claude Code statusline — a single bash script (`statusline.sh`) that transforms Claude Code's JSON session data into a 6-line colored terminal display showing hostname, directory/git info, environment, context usage, session timer, cost/tokens, and rotating tips. Uses Nerd Font icons (requires a patched Nerd Font like FiraCode Nerd Font Mono as terminal font).

Based on the npm package `@chongdashu/cc-statusline` v1.4.0. Source: https://github.com/chongdashu/cc-statusline

## No Build/Test/Lint

This is a standalone bash script with no build system, test suite, or linter. To test changes, run it with sample JSON piped to stdin:

```bash
echo '{"cwd":"/tmp","model":"claude-opus-4-6","contextWindow":{"used":0.15,"total":200000}}' | bash statusline.sh
```

The script is deployed to `~/.claude/statusline.sh` and configured via `~/.claude/settings.json`.

## Architecture

**Input:** JSON from Claude Code piped via stdin
**Output:** 6 lines of ANSI-colored text
**Dependencies:** `jq` (optional, has pure-bash fallback), `git` (optional), Nerd Font (terminal font)

### Script Structure (statusline.sh)

| Lines     | Section                                                    |
|-----------|------------------------------------------------------------|
| 1–20      | Header, version, input capture, jq detection               |
| 21–32     | Color helper functions (ANSI 256-color)                    |
| 33–80     | JSON extraction utilities (jq primary, grep/sed fallback)  |
| 83–130    | Data extraction: directory, model, MCP, hooks              |
| 132–192   | Git integration: branch, changes, ahead/behind, stash      |
| 194–228   | Context window percentage calculation                      |
| 230–294   | Cost, token counts, burn rate, tokens/minute               |
| 296–314   | Session reset time (5-hour rolling window)                 |
| 315–317   | Hostname detection                                         |
| 319–406   | Rendering: assembles and prints the 6 output lines         |
| 408–464   | Tips array (45 entries) and final output                   |

### Key Design Patterns

- **Graceful degradation:** Every feature has a fallback. jq unavailable → bash parsing. Git unavailable → skip git line. Missing JSON fields → sensible defaults.
- **Dual JSON parsing:** `HAS_JQ` flag controls whether `jq` or `extract_json_string()` (grep/sed) is used.
- **Dynamic colors:** Context bar color shifts green→peach→red based on usage %. Session timer color shifts similarly.
- **Data sources:** Session JSON (stdin) for model/context/cost, `~/.claude/settings.json` for MCP/hooks counts, `git` commands for repo status, `hostname` for computer name.

### Icons

All icons use Nerd Font glyphs (Material Design and FontAwesome sets). Icons are embedded as literal UTF-8 characters in the script, not escape sequences. Each icon is color-matched to its associated text by placing it after the color function's `%s` in the printf format string.

To change an icon: look up the codepoint on the [Nerd Font cheat sheet](https://www.nerdfonts.com/cheat-sheet), encode it as UTF-8, and replace the bytes in the script using `sed` with `printf '\U000XXXXX'` for the character. The FA icon range (U+E000-U+F8FF) may not render in all Nerd Fonts — prefer Material Design icons (U+F0000+) for broader compatibility.

| Icon | Nerd Font | Codepoint | Usage |
|------|-----------|-----------|-------|
| Home | `nf-fa-home` | `U+F015` | Hostname |
| Folder | `nf-fa-folder` | `U+F07B` | Directory |
| Git branch | `nf-dev-git_branch` | `U+E725` | Branch name |
| Save | `nf-md-content_save` | `U+F0197` | Git stash |
| Robot | `nf-md-robot_happy` | `U+F1719` | Model name |
| Tag | `nf-md-tag_text` | `U+F1224` | CC version |
| Comment | `nf-md-comment` | `U+F017A` | Output style |
| Connection | `nf-md-connection` | `U+F1616` | MCP servers |
| Link | `nf-md-link_variant` | `U+F06E2` | Hooks |
| Brain | `nf-md-brain` | `U+F09D1` | Context usage |
| Timer | `nf-md-timer_outline` | `U+F051B` | Session timer |
| Sack | `nf-md-sack` | `U+F0D2E` | Cost |
| Chart | `nf-md-chart_bar` | `U+F0127` | Token stats |
| Lightbulb | `nf-md-lightbulb_on_outline` | `U+F06E9` | Tips |

### Customization Points

- **Colors:** Edit the named color functions (e.g., `dir_color()`, `model_color()`) near line 25.
- **Icons:** Nerd Font glyphs are embedded directly in printf statements in the render section (~line 320+). See icon table above.
- **Progress bar:** Width set in render section (~line 375), characters in `progress_bar()` function (~line 50).
- **Tips:** Array starting ~line 430. Rotation speed controlled by divisor in `$(date +%s) / 60`.
