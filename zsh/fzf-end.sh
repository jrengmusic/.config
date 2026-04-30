#!/usr/bin/env bash

file="$1"

is_image() {
    [[ "${1##*.}" =~ ^(jpg|jpeg|png|gif|bmp|webp|svg|tiff|tif|avif|jxl|qoi|xwd)$ ]]
}

if [[ -d "$file" ]]; then
    if command -v eza &>/dev/null; then
        eza --color=always -la "$file"
    else
        ls -la "$file"
    fi
elif is_image "$file"; then
    end preview "$file"
else
    bat --color=always --style=numbers --line-range=:500 "$file"
fi
