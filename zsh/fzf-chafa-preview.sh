#!/usr/bin/env bash

file="$1"
dim="${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}"

is_image() {
    [[ "${1##*.}" =~ ^(jpg|jpeg|png|gif|bmp|webp|svg|tiff|tif|avif|jxl|qoi|xwd)$ ]]
}

chafa_format() {
    local fmt="symbols"
    if [[ "$TERM_PROGRAM" == "END" ]]; then
        fmt="kitty"
    fi
    printf "%s" "$fmt"
}

if [[ -d "$file" ]]; then
    if command -v eza &>/dev/null; then
        eza --color=always -la "$file"
    else
        ls -la "$file"
    fi
elif is_image "$file"; then
    if command -v chafa &>/dev/null; then
        chafa --format="$(chafa_format)" -s "$dim" "$file"
    else
        file "$file"
    fi
else
    bat --color=always --style=numbers --line-range=:500 "$file"
fi
