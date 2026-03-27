#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For Rofi Beats to play online Music or Locally saved media files

# Variables
mDIR="$HOME/Music/"
iDIR="$HOME/.config/swaync/icons"
rofi_theme="$HOME/.config/rofi/config-rofi-Beats.rasi"
rofi_theme_1="$HOME/.config/rofi/config-rofi-Beats-menu.rasi"

# Online Stations. Edit as required
declare -A online_music=(
  # ["NAME📻🎶"]="LINK"
  ["BackEnd Sadrach"]="https://www.youtube.com/playlist?list=PLXuOK4h_ZtSbGV1FsT_nC0TRlf2EmwXEE"
  ["Heavy Hitters Sadrach"]="https://www.youtube.com/playlist?list=RDCLAK5uy_nVT2-bFfxplES7OQSLcnwlJqpsQ9gn0yY"
  ["Radio - Lofi Girl 🎧🎶"]="https://play.streamafrica.net/lofiradio"
  ["YT - Relaxing Piano Music 🎹🎶"]="https://youtu.be/6H7hXzjFoVU?si=nZTPREC9lnK1JJUG"
  ["YT - Youtube Remix 📹🎶"]="https://youtube.com/playlist?list=PLeqTkIUlrZXlSNn3tcXAa-zbo95j0iN-0"
  ["YT - lofi hip hop radio beats 📹🎶"]="https://www.youtube.com/live/jfKfPfyJRdk?si=PnJIA9ErQIAw6-qd"
)

# Populate local_music array with files from music directory and subdirectories
populate_local_music() {
  local_music=()
  filenames=()
  while IFS= read -r file; do
    local_music+=("$file")
    filenames+=("$(basename "$file")")
  done < <(find -L "$mDIR" -type f \( -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.ogg" -o -iname "*.mp4" \))
}

# Function for displaying notifications
notification() {
  notify-send -u normal -i "$iDIR/music.png" "Now Playing:" "$@"
}

# Function to clean mpv socket
clean_socket() {
  if [ -e /tmp/mpvsocket ]; then
    rm -f /tmp/mpvsocket
  fi
}

# Main function for playing local music
play_local_music() {
  populate_local_music

  # Prompt the user to select a song
  choice=$(printf "%s\n" "${filenames[@]}" | rofi -i -dmenu -config $rofi_theme)

  if [ -z "$choice" ]; then
    exit 1
  fi

  # Find the corresponding file path based on user's choice and set that to play the song then continue on the list
  for (( i=0; i<"${#filenames[@]}"; ++i )); do
    if [ "${filenames[$i]}" = "$choice" ]; then

      if music_playing; then
        stop_music
      fi
      clean_socket
	    notification "$choice"
      mpv --input-ipc-server=/tmp/mpvsocket --playlist-start="$i" --loop-playlist --vid=no --no-audio-display --audio-device=auto --ao=pulse,alsa,  "${local_music[@]}"

      break
    fi
  done
}

# Main function for shuffling local music
shuffle_local_music() {
  if music_playing; then
    stop_music
  fi
  clean_socket
  notification "Shuffle Play local music"

  # Play music in $mDIR on shuffle
  mpv --input-ipc-server=/tmp/mpvsocket --shuffle --loop-playlist --vid=no --no-audio-display --audio-device=auto --ao=pulse,alsa, "$mDIR"
}

# Main function for playing online music
play_online_music() {
  choice=$(for online in "${!online_music[@]}"; do
      echo "$online"
    done | sort | rofi -i -dmenu -config "$rofi_theme")

  if [ -z "$choice" ]; then
    exit 1
  fi

  link="${online_music[$choice]}"

  if music_playing; then
    stop_music
  fi
  clean_socket
  notification "$choice"
  
  # Play the selected online music using mpv
  # Remove --shuffle for playlists, let the playlist play in order
  mpv --shuffle --input-ipc-server=/tmp/mpvsocket --vid=no --no-audio-display --audio-device=auto --ao=pipewire,pulse,alsa "$link"
}

# Function to check if music is already playing
music_playing() {
  pgrep -x "mpv" > /dev/null
}

# Function to stop music and kill mpv processes
stop_music() {
  mpv_pids=$(pgrep -x mpv)

  if [ -n "$mpv_pids" ]; then
    # Get the PID of the mpv process used by mpvpaper (using the unique argument added)
    mpvpaper_pid=$(ps aux | grep -- 'unique-wallpaper-process' | grep -v 'grep' | awk '{print $2}')

    for pid in $mpv_pids; do
      if ! echo "$mpvpaper_pid" | grep -q "$pid"; then
        kill -9 $pid || true 
      fi
    done
    clean_socket
    notify-send -u low -i "$iDIR/music.png" "Music stopped" || true
  fi
}

# Function to pause/play music
toggle_music() {
  echo '{ "command": ["cycle", "pause"] }' | socat - /tmp/mpvsocket
  notify-send -u low -i "$iDIR/music.png" "Music toggled"
}

# Function to play next track
next_track() {
  echo '{ "command": ["playlist-next"] }' | socat - /tmp/mpvsocket
  notify-send -u low -i "$iDIR/music.png" "Next track"
}

# Function to play previous track
previous_track() {
  echo '{ "command": ["playlist-prev"] }' | socat - /tmp/mpvsocket
  notify-send -u low -i "$iDIR/music.png" "Previous track"
}

# Check if music is playing and show appropriate menu
if music_playing; then
  user_choice=$(printf "%s\n" \
    "⏯️  Pause/Play" \
    "⏭️  Next Track" \
    "⏮️  Previous Track" \
    "⏹️  Stop RofiBeats" \
    | rofi -dmenu -config $rofi_theme_1)
else
  user_choice=$(printf "%s\n" \
    "Play from Online Stations" \
    "Play from Music directory" \
    "Shuffle Play from Music directory" \
    "Stop RofiBeats" \
    | rofi -dmenu -config $rofi_theme_1)
fi

echo "User choice: $user_choice"

case "$user_choice" in
  "Play from Online Stations")
    play_online_music
    ;;
  "Play from Music directory")
    play_local_music
    ;;
  "Shuffle Play from Music directory")
    shuffle_local_music
    ;;
  "⏯️  Pause/Play")
    toggle_music
    ;;
  "⏭️  Next Track")
    next_track
    ;;
  "⏮️  Previous Track")
    previous_track
    ;;
  "Stop RofiBeats"|"⏹️  Stop RofiBeats")
    if music_playing; then
      stop_music
    fi
    ;;
  *)
    ;;
esac
