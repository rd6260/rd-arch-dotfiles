#!/bin/bash

awww img "$1" \
  --transition-type wave \
  --transition-duration 2 \
  --transition-fps 60 \
  --transition-step 90 \
  --transition-angle 45 \
  --transition-bezier .25,1,.25,1

# matugen image "$1" --source-color-index 0 --json hex > ~/.config/wayfire/assets/shared/colors.json
matugen image "$1" --source-color-index 0

# Store last used wallpaper filename in cache
mkdir -p ~/.cache/wallpicker
basename "$1" > ~/.cache/wallpicker/last_wallpaper
