#!/bin/bash

# Script to toggle Quickshell overview with automatic startup
# Author: Generated for sadrach's Hyprland setup

# Check if quickshell is running
if ! pgrep -x "quickshell" > /dev/null; then
    echo "Quickshell not running, starting it..."
    # Start quickshell in background
    nohup quickshell > /dev/null 2>&1 &
    # Wait a moment for it to initialize
    sleep 2
fi

# Check if quickshell is now running
if pgrep -x "quickshell" > /dev/null; then
    echo "Toggling overview..."
    # Send the toggle command to quickshell
    quickshell -c "GlobalStates.overviewOpen = !GlobalStates.overviewOpen" 2>/dev/null || \
    hyprctl dispatch global "quickshell:overviewToggle" 2>/dev/null || \
    echo "Failed to toggle overview"
else
    echo "Failed to start quickshell"
    # Fallback to rofi if quickshell fails
    pkill rofi || true && rofi -show drun -modi drun,filebrowser,run,window
fi