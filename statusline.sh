#!/bin/bash
#
# Original script: https://github.com/chongdashu/cc-statusline
#
# Custom Claude Code statusline - Created: 2026-02-02T19:27:47.315Z
# Theme: detailed | Colors: true | Features: directory, git, model, context, usage, tokens, burnrate, session
STATUSLINE_VERSION="1.0.1"

input=$(cat)

# ---- check jq availability ----
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
fi

# ---- color helpers (force colors for Claude Code) ----
use_color=1
[ -n "$NO_COLOR" ] && use_color=0

C() { if [ "$use_color" -eq 1 ]; then printf '\033[%sm' "$1"; fi; }
RST() { if [ "$use_color" -eq 1 ]; then printf '\033[0m'; fi; }

# ---- modern sleek colors ----
dir_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;117m'; fi; }    # sky blue
model_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;147m'; fi; }  # light purple  
version_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;180m'; fi; } # soft yellow
cc_version_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;249m'; fi; } # light gray
style_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;245m'; fi; } # gray
rst() { if [ "$use_color" -eq 1 ]; then printf '\033[0m'; fi; }

# ---- time helpers ----
fmt_time_hm() {
  epoch="$1"
  if date -r 0 +%s >/dev/null 2>&1; then date -r "$epoch" +"%H:%M"; else date -d "@$epoch" +"%H:%M"; fi
}

progress_bar() {
  pct="${1:-0}"; width="${2:-10}"
  [[ "$pct" =~ ^[0-9]+$ ]] || pct=0; ((pct<0))&&pct=0; ((pct>100))&&pct=100
  filled=$(( pct * width / 100 )); empty=$(( width - filled ))
  for ((i=0; i<filled; i++)); do printf '■'; done
  for ((i=0; i<empty; i++)); do printf '□'; done
}

# git utilities
num_or_zero() { v="$1"; [[ "$v" =~ ^[0-9]+$ ]] && echo "$v" || echo 0; }

# ---- JSON extraction utilities ----
# Pure bash JSON value extractor (fallback when jq not available)
extract_json_string() {
  local json="$1"
  local key="$2"
  local default="${3:-}"
  
  # For nested keys like workspace.current_dir, get the last part
  local field="${key##*.}"
  field="${field%% *}"  # Remove any jq operators
  
  # Try to extract string value (quoted)
  local value=$(echo "$json" | grep -o "\"\${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
  
  # Convert escaped backslashes to forward slashes for Windows paths
  if [ -n "$value" ]; then
    value=$(echo "$value" | sed 's/\\\\/\//g')
  fi
  
  # If no string value found, try to extract number value (unquoted)
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    value=$(echo "$json" | grep -o "\"\${field}\"[[:space:]]*:[[:space:]]*[0-9.]\+" | head -1 | sed 's/.*:[[:space:]]*\([0-9.]\+\).*/\1/')
  fi
  
  # Return value or default
  if [ -n "$value" ] && [ "$value" != "null" ]; then
    echo "$value"
  else
    echo "$default"
  fi
}

# ---- basics ----
if [ "$HAS_JQ" -eq 1 ]; then
  current_dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "unknown"' 2>/dev/null | sed "s|^$HOME|~|g")
  model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null)

  session_id=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null)
  cc_version=$(echo "$input" | jq -r '.version // ""' 2>/dev/null)
  output_style=$(echo "$input" | jq -r '.output_style.name // ""' 2>/dev/null)
  # Read MCP servers from settings file
  mcp_server_total=$(jq -r '.enabledMcpjsonServers | length // 0' ~/.claude/settings.json 2>/dev/null)
  mcp_server_active="$mcp_server_total"  # Assume all enabled are active
  # Read hooks count from settings file
  hooks_count=$(jq -r '.hooks | keys | length // 0' ~/.claude/settings.json 2>/dev/null)
else
  # Bash fallback for JSON extraction
  # Extract current_dir from workspace object - look for the pattern workspace":{"current_dir":"..."}
  current_dir=$(echo "$input" | grep -o '"workspace"[[:space:]]*:[[:space:]]*{[^}]*"current_dir"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"current_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/\\\\/\//g')
  
  # Fall back to cwd if workspace extraction failed
  if [ -z "$current_dir" ] || [ "$current_dir" = "null" ]; then
    current_dir=$(echo "$input" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | sed 's/\\\\/\//g')
  fi
  
  # Fallback to unknown if all extraction failed
  [ -z "$current_dir" ] && current_dir="unknown"
  current_dir=$(echo "$current_dir" | sed "s|^$HOME|~|g")
  
  # Extract model name from nested model object
  model_name=$(echo "$input" | grep -o '"model"[[:space:]]*:[[:space:]]*{[^}]*"display_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"display_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  [ -z "$model_name" ] && model_name="Claude"

  session_id=$(extract_json_string "$input" "session_id" "")
  # CC version is at the root level
  cc_version=$(echo "$input" | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  # Output style is nested
  output_style=$(echo "$input" | grep -o '"output_style"[[:space:]]*:[[:space:]]*{[^}]*"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  # MCP server count - read from settings file
  if [ -f ~/.claude/settings.json ]; then
    mcp_server_total=$(grep -o '"enabledMcpjsonServers"[[:space:]]*:[[:space:]]*\[[^]]*\]' ~/.claude/settings.json | grep -o '"[^"]*"' | grep -v 'enabledMcpjsonServers' | wc -l | tr -d ' ')
    mcp_server_active="$mcp_server_total"
    # Hooks count - count hook event types
    hooks_count=$(grep -o '"hooks"[[:space:]]*:' ~/.claude/settings.json | wc -l | tr -d ' ')
  else
    mcp_server_total=0
    mcp_server_active=0
    hooks_count=0
  fi
fi

# ---- git colors ----
git_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;150m'; fi; }  # soft green
rst() { if [ "$use_color" -eq 1 ]; then printf '\033[0m'; fi; }

# ---- git ----
git_branch=""
git_changes=""
git_ahead_behind=""
git_last_commit=""
git_stash_count=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)

  # Count uncommitted changes
  git_status=$(git status --porcelain 2>/dev/null)
  if [ -n "$git_status" ]; then
    added=$(echo "$git_status" | grep -c '^??' || echo 0)
    modified=$(echo "$git_status" | grep -c '^ M\|^M \|^MM\|^AM' || echo 0)
    deleted=$(echo "$git_status" | grep -c '^ D\|^D ' || echo 0)
    staged=$(echo "$git_status" | grep -c '^[MARCD]' || echo 0)

    changes_parts=""
    [ "$added" -gt 0 ] && changes_parts="+${added}"
    [ "$modified" -gt 0 ] && changes_parts="${changes_parts:+$changes_parts }~${modified}"
    [ "$deleted" -gt 0 ] && changes_parts="${changes_parts:+$changes_parts }-${deleted}"
    [ "$staged" -gt 0 ] && changes_parts="${changes_parts:+$changes_parts }●${staged}"

    git_changes="$changes_parts"
  fi

  # Ahead/behind remote
  upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
  if [ -n "$upstream" ]; then
    ahead=$(git rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)
    behind=$(git rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    ab_parts=""
    [ "$ahead" -gt 0 ] && ab_parts="↑${ahead}"
    [ "$behind" -gt 0 ] && ab_parts="${ab_parts:+$ab_parts }↓${behind}"
    git_ahead_behind="$ab_parts"
  fi

  # Last commit time (relative)
  last_commit_epoch=$(git log -1 --format=%ct 2>/dev/null)
  if [ -n "$last_commit_epoch" ]; then
    now_epoch=$(date +%s)
    diff_sec=$(( now_epoch - last_commit_epoch ))
    if [ "$diff_sec" -lt 60 ]; then
      git_last_commit="${diff_sec}s ago"
    elif [ "$diff_sec" -lt 3600 ]; then
      git_last_commit="$(( diff_sec / 60 ))m ago"
    elif [ "$diff_sec" -lt 86400 ]; then
      git_last_commit="$(( diff_sec / 3600 ))h ago"
    else
      git_last_commit="$(( diff_sec / 86400 ))d ago"
    fi
  fi

  # Stash count
  stash_count=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  [ "$stash_count" -gt 0 ] && git_stash_count="$stash_count"
fi

# ---- context window calculation (native) ----
context_pct=""
context_remaining_pct=""
context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;158m'; fi; }  # default mint green

if [ "$HAS_JQ" -eq 1 ]; then
  # Get context window size and current usage from native Claude Code input
  CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)
  USAGE=$(echo "$input" | jq '.context_window.current_usage' 2>/dev/null)

  if [ "$USAGE" != "null" ] && [ -n "$USAGE" ]; then
    # Calculate current context from current_usage fields
    # Formula: input_tokens + cache_creation_input_tokens + cache_read_input_tokens
    CURRENT_TOKENS=$(echo "$USAGE" | jq '(.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)' 2>/dev/null)

    if [ -n "$CURRENT_TOKENS" ] && [ "$CURRENT_TOKENS" -gt 0 ] 2>/dev/null; then
      context_used_pct=$(( CURRENT_TOKENS * 100 / CONTEXT_SIZE ))
      context_remaining_pct=$(( 100 - context_used_pct ))
      # Clamp to valid range
      (( context_remaining_pct < 0 )) && context_remaining_pct=0
      (( context_remaining_pct > 100 )) && context_remaining_pct=100

      # Set color based on used percentage
      if [ "$context_used_pct" -ge 71 ]; then
        context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;203m'; fi; }  # coral red
      elif [ "$context_used_pct" -ge 51 ]; then
        context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;215m'; fi; }  # peach
      else
        context_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;158m'; fi; }  # mint green
      fi

      context_pct="${context_used_pct}%"
    fi
  fi
fi

# ---- usage colors ----
usage_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;189m'; fi; }  # lavender
cost_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;222m'; fi; }   # light gold
burn_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;220m'; fi; }   # bright gold
session_color() { 
  rem_pct=$(( 100 - session_pct ))
  if   (( rem_pct <= 10 )); then SCLR='38;5;210'  # light pink
  elif (( rem_pct <= 25 )); then SCLR='38;5;228'  # light yellow  
  else                          SCLR='38;5;194'; fi  # light green
  if [ "$use_color" -eq 1 ]; then printf '\033[%sm' "$SCLR"; fi
}

# ---- cost and usage extraction ----
session_txt=""; session_pct=0; session_bar=""
cost_usd=""; cost_per_hour=""; tpm=""; tot_tokens=""

# Extract cost and token data from Claude Code's native input
if [ "$HAS_JQ" -eq 1 ]; then
  # Cost data
  cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
  total_duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty' 2>/dev/null)

  # Calculate burn rate ($/hour) from cost and duration
  if [ -n "$cost_usd" ] && [ -n "$total_duration_ms" ] && [ "$total_duration_ms" -gt 0 ]; then
    cost_per_hour=$(echo "$cost_usd $total_duration_ms" | awk '{printf "%.2f", $1 * 3600000 / $2}')
  fi

  # Token data from native context_window (no ccusage needed)
  input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0' 2>/dev/null)
  output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0' 2>/dev/null)

  if [ "$input_tokens" != "null" ] && [ "$output_tokens" != "null" ]; then
    tot_tokens=$(( input_tokens + output_tokens ))
    [ "$tot_tokens" -eq 0 ] && tot_tokens=""
  fi

  # Calculate tokens per minute from native data
  if [ -n "$tot_tokens" ] && [ -n "$total_duration_ms" ] && [ "$total_duration_ms" -gt 0 ]; then
    # Convert ms to minutes and calculate rate
    tpm=$(echo "$tot_tokens $total_duration_ms" | awk '{if ($2 > 0) printf "%.0f", $1 * 60000 / $2; else print ""}')
  fi
else
  # Bash fallback for cost extraction
  cost_usd=$(echo "$input" | grep -o '"total_cost_usd"[[:space:]]*:[[:space:]]*[0-9.]*' | sed 's/.*:[[:space:]]*\([0-9.]*\).*/\1/')
  total_duration_ms=$(echo "$input" | grep -o '"total_duration_ms"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*:[[:space:]]*\([0-9]*\).*/\1/')

  # Calculate burn rate ($/hour) from cost and duration
  if [ -n "$cost_usd" ] && [ -n "$total_duration_ms" ] && [ "$total_duration_ms" -gt 0 ]; then
    cost_per_hour=$(echo "$cost_usd $total_duration_ms" | awk '{printf "%.2f", $1 * 3600000 / $2}')
  fi

  # Token data from native context_window (bash fallback)
  input_tokens=$(echo "$input" | grep -o '"total_input_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*:[[:space:]]*\([0-9]*\).*/\1/')
  output_tokens=$(echo "$input" | grep -o '"total_output_tokens"[[:space:]]*:[[:space:]]*[0-9]*' | sed 's/.*:[[:space:]]*\([0-9]*\).*/\1/')

  if [ -n "$input_tokens" ] && [ -n "$output_tokens" ]; then
    tot_tokens=$(( input_tokens + output_tokens ))
    [ "$tot_tokens" -eq 0 ] && tot_tokens=""
  fi

  # Calculate tokens per minute from native data
  if [ -n "$tot_tokens" ] && [ -n "$total_duration_ms" ] && [ "$total_duration_ms" -gt 0 ]; then
    tpm=$(echo "$tot_tokens $total_duration_ms" | awk '{if ($2 > 0) printf "%.0f", $1 * 60000 / $2; else print ""}')
  fi
fi

# Session reset time (5-hour rolling window, no external tools needed)
now_utc=$(date -u +%s)
utc_seconds_today=$(( now_utc % 86400 ))
midnight_utc=$(( now_utc - utc_seconds_today ))
utc_hour=$(date -u +%H)
utc_hour=$((10#$utc_hour))
block_start_hour=$(( (utc_hour / 5) * 5 ))
block_start_sec=$(( midnight_utc + block_start_hour * 3600 ))
block_end_sec=$(( block_start_sec + 5 * 3600 ))

elapsed=$(( now_utc - block_start_sec ))
total=$(( 5 * 3600 ))
session_pct=$(( elapsed * 100 / total ))
remaining=$(( block_end_sec - now_utc ))
(( remaining < 0 )) && remaining=0
rh=$(( remaining / 3600 )); rm=$(( (remaining % 3600) / 60 ))
end_hm=$(fmt_time_hm "$block_end_sec")
session_txt="$(printf '%dh %dm until reset at %s (%d%%)' "$rh" "$rm" "$end_hm" "$session_pct")"
session_bar=$(progress_bar "$session_pct" 10)

# ---- hostname ----
host_name=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo "unknown")
host_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;183m'; fi; }  # soft pink/mauve

# ---- render statusline ----
# Line 1: Directory, hostname, and git
printf '%s %s%s  %s %s%s' "$(host_color)" "$host_name" "$(rst)" "$(dir_color)" "$current_dir" "$(rst)"
if [ -n "$git_branch" ]; then
  printf '  %s %s%s' "$(git_color)" "$git_branch" "$(rst)"
  if [ -n "$git_changes" ]; then
    printf ' %s[%s]%s' "$(git_color)" "$git_changes" "$(rst)"
  fi
  if [ -n "$git_ahead_behind" ]; then
    printf ' %s%s%s' "$(git_color)" "$git_ahead_behind" "$(rst)"
  fi
  if [ -n "$git_last_commit" ]; then
    printf ' %s(%s)%s' "$(git_color)" "$git_last_commit" "$(rst)"
  fi
  if [ -n "$git_stash_count" ]; then
    printf ' %s󰆗 %s%s' "$(git_color)" "$git_stash_count" "$(rst)"
  fi
fi

# Line 2: Model, version, style, MCP
printf '\n%s󱜙 %s%s' "$(model_color)" "$model_name" "$(rst)"
if [ -n "$cc_version" ] && [ "$cc_version" != "null" ]; then
  printf '  %s󱈤 v%s%s' "$(cc_version_color)" "$cc_version" "$(rst)"
fi
if [ -n "$output_style" ] && [ "$output_style" != "null" ]; then
  printf '  %s󰅺 %s%s' "$(cc_version_color)" "$output_style" "$(rst)"
fi
if [ -n "$mcp_server_total" ] && [ "$mcp_server_total" -gt 0 ] 2>/dev/null; then
  printf '  %s󱘖 %s MCP%s' "$(cc_version_color)" "$mcp_server_total" "$(rst)"
fi
if [ -n "$hooks_count" ] && [ "$hooks_count" -gt 0 ] 2>/dev/null; then
  hooks_label="hooks"; [ "$hooks_count" -eq 1 ] && hooks_label="hook"
  printf '  %s󰛢 %s %s%s' "$(cc_version_color)" "$hooks_count" "$hooks_label" "$(rst)"
fi

# Line 3: Context and session time
if [ -n "$context_pct" ]; then
  context_bar=$(progress_bar "$context_used_pct" 60)
  printf '\n%s󰧑 Context Used: %s [%s]%s' "$(context_color)" "$context_pct" "$context_bar" "$(rst)"
else
  printf '\n%s󰧑 Context Used: 0%% [□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□□]%s' "$(context_color)" "$(rst)"
fi
if [ -n "$session_txt" ]; then
  printf '\n%s󰔛 %s%s %s[%s]%s' "$(session_color)" "$session_txt" "$(rst)" "$(session_color)" "$session_bar" "$(rst)"
fi

# Line 3: Cost and usage analytics
line3=""
if [ -n "$cost_usd" ] && [[ "$cost_usd" =~ ^[0-9.]+$ ]]; then
  if [ -n "$cost_per_hour" ] && [[ "$cost_per_hour" =~ ^[0-9.]+$ ]]; then
    cost_per_hour_formatted=$(printf '%.2f' "$cost_per_hour")
    line3="$(cost_color)󰴮 \$$(printf '%.2f' "$cost_usd")$(rst) ($(burn_color)\$${cost_per_hour_formatted}/h$(rst))"
  else
    line3="$(cost_color)󰴮 \$$(printf '%.2f' "$cost_usd")$(rst)"
  fi
fi
if [ -n "$tot_tokens" ] && [[ "$tot_tokens" =~ ^[0-9]+$ ]]; then
  # Format input/output token split
  token_split=""
  if [ -n "$input_tokens" ] && [ -n "$output_tokens" ] && [ "$input_tokens" -gt 0 -o "$output_tokens" -gt 0 ] 2>/dev/null; then
    token_split="${input_tokens} in / ${output_tokens} out"
  else
    token_split="${tot_tokens} tok"
  fi

  if [ -n "$tpm" ] && [[ "$tpm" =~ ^[0-9.]+$ ]]; then
    tpm_formatted=$(printf '%.0f' "$tpm")
    if [ -n "$line3" ]; then
      line3="$line3  $(usage_color)󰄧 ${token_split} (${tpm_formatted} tpm)$(rst)"
    else
      line3="$(usage_color)󰄧 ${token_split} (${tpm_formatted} tpm)$(rst)"
    fi
  else
    if [ -n "$line3" ]; then
      line3="$line3  $(usage_color)󰄧 ${token_split}$(rst)"
    else
      line3="$(usage_color)󰄧 ${token_split}$(rst)"
    fi
  fi
fi

# Print lines
if [ -n "$line3" ]; then
  printf '\n%s' "$line3"
fi

# Random tip
tips=(
  "Shift+Tab to accept a file edit"
  "Esc to interrupt Claude"
  "Use /clear to reset conversation"
  "Shift+O to change output style"
  "Use @ to add files to context"
  "Ctrl+R to search command history"
  "/config to adjust settings"
  "Use #tag to reference code"
  "/cost to see session costs"
  "/compact to summarize conversation"
  "Use ! prefix for shell commands"
  "/vim for vim keybindings"
  "Ctrl+Space to toggle autocomplete"
  "/pr to create a pull request"
  "/review-pr to review changes"
  "/memory to save project notes"
  "Up arrow to edit last message"
  "/resume to continue a past session"
  "Use images: paste or drag into prompt"
  "/mcp to manage MCP servers"
  "Tab twice for file autocomplete"
  "/init to create CLAUDE.md"
  "Ctrl+C twice to force quit"
  "/doctor to diagnose issues"
  "Drag folders into prompt for context"
  "/model to switch models"
  "Use --continue flag to resume last session"
  "/permissions to manage tool access"
  "Use plan mode for complex tasks"
  "Claude reads CLAUDE.md automatically"
  "/diff to see pending changes"
  "Shift+Enter for multi-line input"
  "/status to check API status"
  "Use --print for non-interactive mode"
  "/hooks to configure automation"
  "Ctrl+L to clear screen"
  "Add .claudeignore to exclude files"
  "/commit to commit with AI message"
  "Use headless mode for CI/CD"
  "Opus for complex, Haiku for simple tasks"
  "/bug to report issues"
  "Use --allowedTools to restrict tools"
  "Sonnet balances speed and capability"
  "/logout to switch accounts"
  "Use CLAUDE.local.md for personal notes"
  "Ctrl+Z to undo last action"
  "/listen for voice input"
  "Set hooks for notifications on completion"
  "Use subagents for parallel tasks"
  "/terminal-setup for shell integration"
)
tip_color() { if [ "$use_color" -eq 1 ]; then printf '\033[38;5;243m'; fi; }  # dim gray
tip_index=$(( $(date +%s) / 60 % ${#tips[@]} ))  # Rotate every minute
printf '\n%s󰛩 %s%s' "$(tip_color)" "${tips[$tip_index]}" "$(rst)"
printf '\n'
