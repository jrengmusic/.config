#!/bin/bash

CURRENT_PANE=$(tmux display-message -p "#{pane_id}")
CURRENT_PATH=$(tmux display-message -p "#{pane_current_path}")

# Split into 3 vertical panes (30-40-30)
tmux split-window -h -p 40 -c "$CURRENT_PATH" \; \
  select-pane -t "$CURRENT_PANE" \; \
  split-window -h -p 75 -c "$CURRENT_PATH" \; \
  select-layout -t "${CURRENT_PANE}.*" main-horizontal
