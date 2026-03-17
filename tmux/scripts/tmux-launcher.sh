#!/usr/bin/env bash
# Configuration
MENU_TITLE="───────────   SESSIONS ───────────"
NEW="New"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
current_session=$(tmux display-message -p '#{session_name}')
other_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep -v "^${current_session}$")
other_count=0
if [ -n "$other_sessions" ]; then
    other_count=$(echo "$other_sessions" | wc -l | tr -d ' ')
fi

if [ "$other_count" -eq 0 ]; then
    # No other sessions — rename current to today's date
    today=$(date +"%A")
    tmux rename-session -t "$current_session" "$today"

elif [ "$other_count" -eq 1 ]; then
    # One other session — switch to it, kill the temp one
    target=$(echo "$other_sessions" | head -1)
    tmux switch-client -t "$target"
    tmux kill-session -t "$current_session"

else
    # Multiple sessions — show menu
    menu_cmd="tmux display-menu -x C -y C -T '#[align=centre]$MENU_TITLE'"
    while IFS= read -r session; do
        menu_cmd="$menu_cmd \"$session\" \"\" \"switch-client -t '$session' ; kill-session -t '$current_session'\""
    done <<< "$other_sessions"

    menu_cmd="$menu_cmd \"\" \"\" \"\""
    menu_cmd="$menu_cmd \"$NEW\" \"\" \"command-prompt -p 'Session name:' 'rename-session -t $current_session %%'\""
    eval "$menu_cmd"
fi
