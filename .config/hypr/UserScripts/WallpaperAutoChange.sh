#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Contributor: sadrach34 (mods and maintenance)
# source https://wiki.archlinux.org/title/Hyprland#Using_a_script_to_change_wallpaper_every_X_minutes

# This script will randomly go through the files of a directory, setting it
# up as the wallpaper at regular intervals
#
# NOTE: this script uses bash (not POSIX shell) for the RANDOM variable

# Prevent multiple instances
PIDFILE="/tmp/wallpaper_auto_change.pid"
if [ -f "$PIDFILE" ]; then
    if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Script is already running with PID $(cat "$PIDFILE")"
        exit 1
    else
        rm -f "$PIDFILE"
    fi
fi
echo $$ > "$PIDFILE"

# Cleanup on exit
trap 'rm -f "$PIDFILE"; exit' INT TERM EXIT

wallust_refresh=$HOME/.config/hypr/scripts/RefreshNoWaybar.sh

focused_monitor=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

if [[ $# -lt 1 ]] || [[ ! -d $1   ]]; then
	echo "Usage:
	$0 <dir containing images>"
	exit 1
fi

# Edit below to control the images transition
export SWWW_TRANSITION_FPS=60
export SWWW_TRANSITION_TYPE=simple

# This controls (in seconds) when to switch to the next image
# INTERVAL=1800 #30 minutes
INTERVAL=900	#15 minutes
# INTERVAL=300    #5 minutes
# INTERVAL=60    #1 minute

while true; do
	# Get all image files and randomize them
	mapfile -t images < <(find "$1" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) | shuf)
	
	for img in "${images[@]}"; do
		if [ ! -f "$PIDFILE" ]; then
			echo "PID file removed, exiting..."
			exit 0
		fi
		
		echo "Setting wallpaper: $img"
		
		# Set wallpaper and wait for it to complete
		swww img -o "$focused_monitor" "$img" --transition-type simple --transition-fps 60
		
		# Wait a moment to ensure swww has processed the change
		sleep 2
		
		# Update rofi wallpaper link for quickshell overview and hyprlock
		ln -sf "$img" "$HOME/.config/rofi/.current_wallpaper"
		
		# Verify the change was applied correctly
		current_wall=$(swww query | grep "currently displaying" | sed 's/.*image: //')
		link_wall=$(readlink "$HOME/.config/rofi/.current_wallpaper")
		
		if [ "$current_wall" != "$link_wall" ]; then
			echo "Warning: Wallpaper mismatch detected"
			echo "swww shows: $current_wall"
			echo "Link points to: $link_wall"
			# Force sync the link to match swww
			ln -sf "$current_wall" "$HOME/.config/rofi/.current_wallpaper"
		fi
		
		# $wallust_refresh
		sleep $INTERVAL
	done
done
