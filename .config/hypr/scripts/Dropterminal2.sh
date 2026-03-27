#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
#
# Made and brought to by Kiran George
# /* -- ✨ https://github.com/SherLock707 ✨ -- */  ##
# Dropdown Terminal — Native Hyprland animation (no manual loops)
# Uses a dedicated special workspace + togglespecialworkspace for smooth GPU animation
#
# Usage: ./Dropterminal2.sh [-d] <terminal_command>
# Example: ./Dropterminal2.sh foot
#          ./Dropterminal2.sh -d foot
#          ./Dropterminal2.sh "kitty -e zsh"

DEBUG=false
SPECIAL_WS_NAME="dropdown"
ADDR_FILE="/tmp/dropdown_terminal_addr"

# Dropdown size and position configuration (percentages)
WIDTH_PERCENT=50  # Width as percentage of screen width
HEIGHT_PERCENT=50 # Height as percentage of screen height
Y_PERCENT=5       # Y position as percentage from top (X is auto-centered)

# Parse arguments
if [ "$1" = "-d" ]; then
  DEBUG=true
  shift
fi

TERMINAL_CMD="$1"

debug_echo() {
  if [ "$DEBUG" = true ]; then
    echo "$@"
  fi
}

if [ -z "$TERMINAL_CMD" ]; then
  echo "Missing terminal command. Usage: $0 [-d] <terminal_command>"
  echo "Examples:"
  echo "  $0 foot"
  echo "  $0 -d foot"
  echo "  $0 'kitty -e zsh'"
  exit 1
fi

# Get focused monitor info including scale and name
get_monitor_info() {
  local monitor_data
  monitor_data=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.name)"')
  if [ -z "$monitor_data" ] || [[ "$monitor_data" =~ ^null ]]; then
    debug_echo "Error: Could not get focused monitor information"
    return 1
  fi
  echo "$monitor_data"
}

# Calculate dropdown position with scaling and auto-centering
calculate_dropdown_position() {
  local monitor_info
  monitor_info=$(get_monitor_info)

  if [ $? -ne 0 ] || [ -z "$monitor_info" ]; then
    debug_echo "Error: Failed to get monitor info, using fallback values"
    echo "100 100 800 600"
    return 1
  fi

  local mon_x mon_y mon_width mon_height mon_scale
  mon_x=$(echo $monitor_info | cut -d' ' -f1)
  mon_y=$(echo $monitor_info | cut -d' ' -f2)
  mon_width=$(echo $monitor_info | cut -d' ' -f3)
  mon_height=$(echo $monitor_info | cut -d' ' -f4)
  mon_scale=$(echo $monitor_info | cut -d' ' -f5)

  if [ -z "$mon_scale" ] || [ "$mon_scale" = "null" ] || [ "$mon_scale" = "0" ]; then
    mon_scale="1.0"
  fi

  local logical_width logical_height
  if command -v bc >/dev/null 2>&1; then
    logical_width=$(echo "scale=0; $mon_width / $mon_scale" | bc | cut -d'.' -f1)
    logical_height=$(echo "scale=0; $mon_height / $mon_scale" | bc | cut -d'.' -f1)
  else
    local scale_int
    scale_int=$(echo "$mon_scale" | sed 's/\.//' | sed 's/^0*//')
    if [ -z "$scale_int" ]; then scale_int=100; fi
    logical_width=$(((mon_width * 100) / scale_int))
    logical_height=$(((mon_height * 100) / scale_int))
  fi

  if ! [[ "$logical_width" =~ ^-?[0-9]+$ ]]; then logical_width=$mon_width; fi
  if ! [[ "$logical_height" =~ ^-?[0-9]+$ ]]; then logical_height=$mon_height; fi

  local width=$((logical_width * WIDTH_PERCENT / 100))
  local height=$((logical_height * HEIGHT_PERCENT / 100))
  local y_offset=$((logical_height * Y_PERCENT / 100))
  local x_offset=$(((logical_width - width) / 2))
  local final_x=$((mon_x + x_offset))
  local final_y=$((mon_y + y_offset))

  debug_echo "Window size: ${width}x${height}, position: ${final_x},${final_y}"
  echo "$final_x $final_y $width $height"
}

# Check if the dropdown special workspace is currently visible on focused monitor
is_dropdown_visible() {
  local monitor_special
  monitor_special=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .specialWorkspace.name')
  [ "$monitor_special" = "special:$SPECIAL_WS_NAME" ]
}

# Get stored terminal address
get_terminal_address() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cat "$ADDR_FILE"
  fi
}

# Check if terminal window still exists
terminal_exists() {
  local addr
  addr=$(get_terminal_address)
  if [ -n "$addr" ]; then
    hyprctl clients -j | jq -e --arg ADDR "$addr" 'any(.[]; .address == $ADDR)' >/dev/null 2>&1
  else
    return 1
  fi
}

# Position and resize the dropdown window
position_dropdown() {
  local addr="$1"
  local pos_info
  pos_info=$(calculate_dropdown_position)

  local target_x target_y width height
  target_x=$(echo $pos_info | cut -d' ' -f1)
  target_y=$(echo $pos_info | cut -d' ' -f2)
  width=$(echo $pos_info | cut -d' ' -f3)
  height=$(echo $pos_info | cut -d' ' -f4)

  hyprctl dispatch resizewindowpixel "exact $width $height,address:$addr" >/dev/null 2>&1
  hyprctl dispatch movewindowpixel "exact $target_x $target_y,address:$addr" >/dev/null 2>&1
  debug_echo "Positioned dropdown at ${target_x},${target_y} size ${width}x${height}"
}

# Spawn a new terminal in the dropdown special workspace
spawn_terminal() {
  debug_echo "Creating new dropdown terminal with command: $TERMINAL_CMD"

  local pos_info
  pos_info=$(calculate_dropdown_position)

  local width height
  width=$(echo $pos_info | cut -d' ' -f3)
  height=$(echo $pos_info | cut -d' ' -f4)

  local windows_before count_before
  windows_before=$(hyprctl clients -j)
  count_before=$(echo "$windows_before" | jq 'length')

  # Spawn terminal directly in the dropdown special workspace
  hyprctl dispatch exec "[float; size $width $height; workspace special:$SPECIAL_WS_NAME silent] $TERMINAL_CMD"

  sleep 0.3

  local windows_after count_after new_addr=""
  windows_after=$(hyprctl clients -j)
  count_after=$(echo "$windows_after" | jq 'length')

  if [ "$count_after" -gt "$count_before" ]; then
    new_addr=$(comm -13 \
      <(echo "$windows_before" | jq -r '.[].address' | sort) \
      <(echo "$windows_after" | jq -r '.[].address' | sort) |
      head -1)
  fi

  if [ -z "$new_addr" ] || [ "$new_addr" = "null" ]; then
    new_addr=$(hyprctl clients -j | jq -r 'sort_by(.focusHistoryID) | .[-1] | .address')
  fi

  if [ -n "$new_addr" ] && [ "$new_addr" != "null" ]; then
    echo "$new_addr" >"$ADDR_FILE"
    debug_echo "Terminal created with address: $new_addr"
    return 0
  fi

  debug_echo "Failed to get terminal address"
  return 1
}

# Main logic
if terminal_exists; then
  TERMINAL_ADDR=$(get_terminal_address)
  debug_echo "Found existing terminal: $TERMINAL_ADDR"

  # Toggle the dropdown special workspace (Hyprland animates natively)
  hyprctl dispatch togglespecialworkspace "$SPECIAL_WS_NAME"

  # If we just showed it, reposition and focus
  sleep 0.05
  if is_dropdown_visible; then
    debug_echo "Dropdown is now visible, positioning..."
    position_dropdown "$TERMINAL_ADDR"
    hyprctl dispatch focuswindow "address:$TERMINAL_ADDR"
  else
    debug_echo "Dropdown is now hidden"
  fi
else
  debug_echo "No existing terminal found, creating new one"
  if spawn_terminal; then
    TERMINAL_ADDR=$(get_terminal_address)
    if [ -n "$TERMINAL_ADDR" ]; then
      # Show the dropdown workspace (terminal was spawned silently)
      hyprctl dispatch togglespecialworkspace "$SPECIAL_WS_NAME"
      sleep 0.05
      position_dropdown "$TERMINAL_ADDR"
      hyprctl dispatch focuswindow "address:$TERMINAL_ADDR"
    fi
  fi
fi