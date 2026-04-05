#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Contributor: sadrach34 (mods and maintenance)
# Script CORREGIDO para Arch Linux

# Detiene todos los portales existentes para empezar de cero
sleep 1
killall xdg-desktop-portal-hyprland
killall xdg-desktop-portal-wlr
killall xdg-desktop-portal-gnome
killall xdg-desktop-portal
sleep 1

# Inicia el portal de Hyprland desde la ruta CORRECTA para Arch
/usr/lib/xdg-desktop-portal-hyprland &

# Inicia el portal principal desde la ruta CORRECTA para Arch
/usr/lib/xdg-desktop-portal &#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For manually starting xdg-desktop-portal-hyprland

sleep 1
killall xdg-desktop-portal-hyprland
killall xdg-desktop-portal-wlr
killall xdg-desktop-portal-gnome
killall xdg-desktop-portal
sleep 1
/usr/lib/xdg-desktop-portal-hyprland &
#/usr/libexec/xdg-desktop-portal-hyprland &
sleep 2
/usr/lib/xdg-desktop-portal &
/usr/libexec/xdg-desktop-portal &

