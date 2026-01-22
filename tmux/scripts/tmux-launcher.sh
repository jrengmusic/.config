#!/usr/bin/env bash
# Configuration
MENU_TITLE="───────────   SESSIONS ───────────"
NEW="New"
CAROL="CAROL"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
current_session=$(tmux display-message -p '#{session_name}')
all_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)
other_sessions=$(echo "$all_sessions" | grep -v "^${current_session}$" || true)
menu_cmd="tmux display-menu -x C -y C -T '#[align=centre]$MENU_TITLE'"
if [ -n "$other_sessions" ]; then
    while IFS= read -r session; do
        menu_cmd="$menu_cmd \"$session\" \"\" \"switch-client -t '$session' ; kill-session -t '$current_session'\""
    done <<< "$other_sessions"
    
    menu_cmd="$menu_cmd \"\" \"\" \"\""
fi
menu_cmd="$menu_cmd \"$NEW\" \"\" \"command-prompt -p 'Session name:' 'rename-session -t $current_session %%'\""
menu_cmd="$menu_cmd \"$CAROL\" \"\" \"command-prompt -p 'CAROL session name:' 'run-shell \\\"$SCRIPT_DIR/tmux-carol.sh %% $current_session\\\"'\""
eval "$menu_cmd"
