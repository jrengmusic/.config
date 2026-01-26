#!/usr/bin/env bash
session_name="$1"
old_session="$2"
full_name="CAROL-${session_name}"

tmux rename-session -t "$old_session" "$full_name"

# Create 3 columns first
tmux split-window -h
tmux split-window -h

# Make columns equal width
tmux select-layout even-horizontal

# Split each column into 2 rows (panes are 1, 2, 3)
tmux split-window -v -t 1
tmux split-window -v -t 3
tmux split-window -v -t 5

# Wait for shells to load
sleep 0.1

# clear artifacts from splitting
tmux list-panes -s -F '#{pane_id}' | while read pane_id; do tmux send-keys -t "$pane_id" clear Enter; done


# role assigning
# tmux send-keys -t "1" 'copilot' Enter
# tmux send-keys -t "3" 'opencode' Enter
# tmux send-keys -t "4" 'amp' Enter
# tmux send-keys -t "6" 'vibe' Enter

# Wait for shells to load
sleep 2
tmux select-pane -t 1 -T COUNSELOR
tmux select-pane -t 2 -T AUDITOR
tmux select-pane -t 3 -T ENGINEER
tmux select-pane -t 4 -T MASCHINIST
tmux select-pane -t 5 -T SURGEON
tmux select-pane -t 6 -T JOURNALIST
