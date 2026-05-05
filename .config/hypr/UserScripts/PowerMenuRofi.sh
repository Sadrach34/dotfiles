#!/usr/bin/env bash
set -euo pipefail

options="  Lock\n  Logout\n  Reboot\n  Shutdown"
choice=$(echo -e "$options" | rofi -dmenu -i -p "Power Menu")

case "$choice" in
    *Lock)     loginctl lock-session ;;
    *Logout)   hyprctl dispatch exit ;;
    *Reboot)   systemctl reboot ;;
    *Shutdown) systemctl poweroff ;;
esac
