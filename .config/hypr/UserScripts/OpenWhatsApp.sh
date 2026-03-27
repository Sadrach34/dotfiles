#!/bin/bash

# Script to open WhatsApp Web in Firefox and focus the window
# Author: Assistant for sadrach

# Function to check if Firefox exists ONLY in normal workspaces
firefox_exists_in_normal() {
    local normal_firefox=$(hyprctl clients -j | jq -r '.[] | select(.class == "firefox" and .workspace.name != "special") | .address' | wc -l)
    [ "$normal_firefox" -gt 0 ]
}

# Function to get Firefox windows not in special workspace
get_firefox_in_normal_workspace() {
    hyprctl clients -j | jq -r '.[] | select(.class == "firefox" and .workspace.name != "special") | .address'
}

# Function to focus first Firefox window in normal workspace
focus_normal_firefox() {
    local firefox_address=$(get_firefox_in_normal_workspace | head -n1)
    if [ -n "$firefox_address" ]; then
        hyprctl dispatch focuswindow "address:$firefox_address"
        return 0
    else
        return 1
    fi
}

# Check if Firefox exists in normal workspaces
if firefox_exists_in_normal; then
    # Firefox exists in normal workspace, open new tab with WhatsApp
    MOZ_ENABLE_WAYLAND=1 firefox --new-tab https://web.whatsapp.com &
    
    # Wait a moment for the tab to load
    sleep 1
    
    # Focus Firefox window in normal workspace (not special)
    focus_normal_firefox
    
elif pgrep -f firefox > /dev/null; then
    # Firefox exists but ONLY in special workspace - start new Firefox instance
    MOZ_ENABLE_WAYLAND=1 firefox --new-instance https://web.whatsapp.com &
    
    # Wait for new Firefox instance to start
    sleep 4
    
    # Focus the new Firefox window
    focus_normal_firefox
    
else
    # Firefox is not running at all, start it with WhatsApp
    MOZ_ENABLE_WAYLAND=1 firefox https://web.whatsapp.com &
    
    # Wait longer for Firefox to fully start
    sleep 4
    
    # Focus the Firefox window
    focus_normal_firefox
fi