#!/usr/bin/env bash

file="$1"

is_image() {
    [[ "${1##*.}" =~ ^(jpg|jpeg|png|gif|bmp|webp|svg|tiff|tif|avif|jxl|qoi|xwd)$ ]]
}

skit_signal() {
    case "$END_SKIT" in
        kitty)  printf '\033_GEND;%s\033\\' "$1" ;;
        iterm2) printf '\033]1337;END;%s\a' "$1" ;;
        sixel)  printf '\033P0qEND;%s\033\\' "$1" ;;
    esac
}

if [[ -d "$file" ]]; then
    skit_signal ""
    if command -v eza &>/dev/null; then
        eza --color=always -la "$file"
    else
        ls -la "$file"
    fi
elif is_image "$file"; then
    skit_signal "$(realpath "$file")"
else
    skit_signal ""
    bat --color=always --style=numbers --line-range=:500 "$file"
fi
