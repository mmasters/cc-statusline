# Claude Code Statusline

Custom statusline for Claude Code displaying session information, git status, and helpful tips.

## Location

```
~/.claude/statusline.sh
```

## Layout

The statusline displays 5 lines:

```
📁 ~/Development/project  🌿 main [+3 ~2] ↑1 ↓2 (2h ago) 📦1
🤖 Opus 4.5  📟 v2.1.29  💬 default  🔌 2 MCP  🪝 1 hook
🧠 Context Used: 15% [■■■■■■■■■□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□]
💰 $0.45 ($12.50/h)  📊 45000 in / 12000 out (1234 tpm)
💡 Shift+Tab to accept a file edit
```

## Line 1: Directory & Git

| Element | Description |
|---------|-------------|
| 📁 | Current working directory |
| 🌿 | Git branch name |
| `[+N ~N -N ●N]` | Uncommitted changes: +added, ~modified, -deleted, ●staged |
| `↑N ↓N` | Commits ahead/behind remote |
| `(Xh ago)` | Time since last commit |
| 📦N | Stash count |

## Line 2: Environment

| Element | Description |
|---------|-------------|
| 🤖 | Model name (Opus 4.5, Sonnet, Haiku) |
| 📟 | Claude Code version |
| 💬 | Output style (default, concise, verbose) |
| 🔌 | MCP servers count (from settings.json) |
| 🪝 | Hooks count (from settings.json) |

## Line 3: Context Usage

| Element | Description |
|---------|-------------|
| 🧠 | Context used percentage with 60-char progress bar |
| Progress bar | `■` = used, `□` = remaining |

**Colors change based on context used:**
- Mint green: ≤50% used
- Peach: 51-70% used
- Coral red: ≥71% used

## Line 4: Cost & Tokens

| Element | Description |
|---------|-------------|
| 💰 | Total session cost in USD |
| `($X/h)` | Burn rate (cost per hour) |
| 📊 | Token split: input / output |
| `(N tpm)` | Tokens per minute |

## Line 5: Tips

| Element | Description |
|---------|-------------|
| 💡 | Random tip, rotates every minute |

## Customization

### Colors

Color functions are defined near the top of the script:

```bash
dir_color()        # 38;5;117 - sky blue
git_color()        # 38;5;150 - soft green
model_color()      # 38;5;147 - light purple
version_color()    # 38;5;180 - soft yellow
cc_version_color() # 38;5;249 - light gray
context_color()    # 38;5;158 - mint green (dynamic)
usage_color()      # 38;5;189 - lavender
cost_color()       # 38;5;222 - light gold
burn_color()       # 38;5;220 - bright gold
tip_color()        # 38;5;243 - dim gray
```

### Progress Bar

To change the progress bar width, edit line ~375:

```bash
context_bar=$(progress_bar "$context_used_pct" 60)  # Change 60 to desired width
```

Also update the fallback on the next line with matching empty squares.

### Progress Bar Characters

To change fill/empty characters, edit the `progress_bar` function (~line 50):

```bash
for ((i=0; i<filled; i++)); do printf '■'; done   # Filled character
for ((i=0; i<empty; i++)); do printf '□'; done    # Empty character
```

### Tips

Tips array starts around line 430. Add or remove tips as needed:

```bash
tips=(
  "Your tip here"
  ...
)
```

Tips rotate based on: `$(date +%s) / 60 % ${#tips[@]}`
- Change `60` to adjust rotation speed (seconds)

### Adding New Elements

1. **Extract data** in the appropriate section (jq for JSON, grep for bash fallback)
2. **Add display** in the render section using printf
3. **Use color functions** for consistent styling

### Data Sources

| Data | Source |
|------|--------|
| Directory, model, context, cost, tokens | Piped JSON from Claude Code |
| Git info | Direct git commands |
| MCP servers, hooks | `~/.claude/settings.json` |

## Dependencies

- `jq` (optional, has bash fallback)
- `git` (for git features)

## Enabling

In `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
  }
}
```
