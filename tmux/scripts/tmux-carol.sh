#!/usr/bin/env bash
session_name="$1"
old_session="$2"
current_path="$3"
full_name="CAROL-${session_name}"

tmux rename-session -t "$old_session" "$full_name"

# Create 3 columns with center pane larger (25% - 50% - 25%)
# First split: create left (25%) and remaining (75%)
tmux split-window -h -p 75 -c "$current_path"
# Second split: split remaining into center (66% of 75% = 50%) and right (33% of 75% = 25%)
tmux split-window -h -p 33 -c "$current_path"

# Wait for shells to load
sleep 0.1

# Clear artifacts from splitting
tmux list-panes -s -F '#{pane_id}' | while read pane_id; do tmux send-keys -t "$pane_id" clear Enter; done

# Wait for shells to load
sleep 0.5

# Role assigning - only PRIMARY agents
# Pane 1 (left): COUNSELOR
tmux select-pane -t 1 -T COUNSELOR
sleep 0.5
tmux send-keys -t 1 'opencode --agent counselor' Enter

# Pane 2 (center): USER (no role assignment)
tmux select-pane -t 2 -T USER

# Pane 3 (right): SURGEON  
tmux select-pane -t 3 -T SURGEON
sleep 0.5
tmux send-keys -t 3 'opencode --agent surgeon' Enter

# Select center pane (user's pane) by default
tmux select-pane -t 2
