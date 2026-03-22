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

# Wait for shells to load
sleep 0.5

# rolse assigning
tmux select-pane -t 1 -T ANALYST
tmux select-pane -t 2 -T INSPECTOR
tmux select-pane -t 4 -T SURGEON
tmux select-pane -t 5 -T CARETAKER



tmux select-pane -t 3 -T SCAFFOLDER


sleep 1
tmux send-keys -t "6" 'vibe "@.carol/CAROL.md you are assigned as JOURNALIST register yourself"' Enter
tmux select-pane -t 6 -T JOURNALIST


