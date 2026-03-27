#!/bin/bash
killall -q xdg-desktop-portal-hyprland
killall -q xdg-desktop-portal
sleep 2
/usr/lib/xdg-desktop-portal-hyprland &
/usr/lib/xdg-desktop-portal &
