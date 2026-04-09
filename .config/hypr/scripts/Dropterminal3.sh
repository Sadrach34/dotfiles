#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Contributor: sadrach34 (mods and maintenance)
#
# Dropdown Terminal — fixed for Hyprland 0.54.1
# Usage: ./Dropdown.sh [-d] <terminal_command>

DEBUG=false
SPECIAL_WS="special:scratchpad"
ADDR_FILE="/tmp/dropdown_terminal_addr"

# Dropdown size and position configuration (percentages)
WIDTH_PERCENT=50
HEIGHT_PERCENT=50
Y_PERCENT=5

# Animation settings
SLIDE_STEPS=5

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
  echo "  $0 -d foot (with debug output)"
  echo "  $0 'kitty -e zsh'"
  echo "  $0 'alacritty --working-directory /home/user'"
  echo ""
  echo "Edit the script to modify size and position:"
  echo "  WIDTH_PERCENT  - Width as percentage of screen (default: 50)"
  echo "  HEIGHT_PERCENT - Height as percentage of screen (default: 50)"
  echo "  Y_PERCENT      - Y position from top as percentage (default: 5)"
  echo "  Note: X position is automatically centered"
  exit 1
fi

get_window_geometry() {
  local addr="$1"
  hyprctl clients -j | jq -r --arg ADDR "$addr" '.[] | select(.address == $ADDR) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"'
}

# ── SLIDE DOWN (show) ─────────────────────────────────────────────────────────
# FIX 0.54.1: window must already be on the current workspace and pinned
# BEFORE we start moving it. No more pin-after-move race condition.
animate_slide_down() {
  local addr="$1"
  local target_x="$2"
  local target_y="$3"
  local width="$4"
  local height="$5"

  debug_echo "Animating slide down → ${target_x},${target_y}"

  local start_y=$((target_y - height - 50))
  local step_y=$(((target_y - start_y) / SLIDE_STEPS))

  # Teleport to off-screen start position (window is already visible/pinned)
  hyprctl dispatch movewindowpixel "exact $target_x $start_y,address:$addr" >/dev/null 2>&1
  sleep 0.04

  for i in $(seq 1 $SLIDE_STEPS); do
    local current_y=$((start_y + (step_y * i)))
    hyprctl dispatch movewindowpixel "exact $target_x $current_y,address:$addr" >/dev/null 2>&1
    sleep 0.03
  done

  # Snap to exact final position
  hyprctl dispatch movewindowpixel "exact $target_x $target_y,address:$addr" >/dev/null 2>&1
}

# ── SLIDE UP (hide) ───────────────────────────────────────────────────────────
# FIX 0.54.1: we do NOT move the window out of the screen before hiding it.
# Instead we animate up, then immediately unpin + send to scratchpad in one
# shot so Hyprland never gets a chance to "correct" the off-screen position.
animate_slide_up() {
  local addr="$1"
  local start_x="$2"
  local start_y="$3"
  local width="$4"
  local height="$5"

  debug_echo "Animating slide up from ${start_x},${start_y}"

  # We only go most of the way up — stopping just before going fully off-screen
  # avoids the 0.54.1 compositor snap-back glitch.
  local end_y=$((start_y - height))
  local step_y=$(((start_y - end_y) / SLIDE_STEPS))

  for i in $(seq 1 $SLIDE_STEPS); do
    local current_y=$((start_y - (step_y * i)))
    hyprctl dispatch movewindowpixel "exact $start_x $current_y,address:$addr" >/dev/null 2>&1
    sleep 0.03
  done

  debug_echo "Slide up animation completed"
}

get_monitor_info() {
  local monitor_data
  monitor_data=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.name)"')
  if [ -z "$monitor_data" ] || [[ "$monitor_data" =~ ^null ]]; then
    debug_echo "Error: Could not get focused monitor information"
    return 1
  fi
  echo "$monitor_data"
}

calculate_dropdown_position() {
  local monitor_info
  monitor_info=$(get_monitor_info)

  if [ $? -ne 0 ] || [ -z "$monitor_info" ]; then
    debug_echo "Error: Failed to get monitor info, using fallback values"
    echo "100 100 800 600 fallback-monitor"
    return 1
  fi

  local mon_x mon_y mon_width mon_height mon_scale mon_name
  mon_x=$(echo $monitor_info | cut -d' ' -f1)
  mon_y=$(echo $monitor_info | cut -d' ' -f2)
  mon_width=$(echo $monitor_info | cut -d' ' -f3)
  mon_height=$(echo $monitor_info | cut -d' ' -f4)
  mon_scale=$(echo $monitor_info | cut -d' ' -f5)
  mon_name=$(echo $monitor_info | cut -d' ' -f6)

  debug_echo "Monitor: x=$mon_x y=$mon_y w=$mon_width h=$mon_height scale=$mon_scale name=$mon_name"

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
    [ -z "$scale_int" ] && scale_int=100
    logical_width=$(((mon_width * 100) / scale_int))
    logical_height=$(((mon_height * 100) / scale_int))
  fi

  if ! [[ "$logical_width" =~ ^-?[0-9]+$ ]]; then logical_width=$mon_width; fi
  if ! [[ "$logical_height" =~ ^-?[0-9]+$ ]]; then logical_height=$mon_height; fi

  local width height y_offset x_offset final_x final_y
  width=$((logical_width * WIDTH_PERCENT / 100))
  height=$((logical_height * HEIGHT_PERCENT / 100))
  y_offset=$((logical_height * Y_PERCENT / 100))
  x_offset=$(((logical_width - width) / 2))
  final_x=$((mon_x + x_offset))
  final_y=$((mon_y + y_offset))

  debug_echo "Logical: ${logical_width}x${logical_height} → window ${width}x${height} @ ${final_x},${final_y}"

  echo "$final_x $final_y $width $height $mon_name"
}

CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')

get_terminal_address() {
  [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ] && cut -d' ' -f1 "$ADDR_FILE"
}

get_terminal_monitor() {
  [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ] && cut -d' ' -f2- "$ADDR_FILE"
}

terminal_exists() {
  local addr
  addr=$(get_terminal_address)
  [ -n "$addr" ] && hyprctl clients -j | jq -e --arg ADDR "$addr" 'any(.[]; .address == $ADDR)' >/dev/null 2>&1
}

terminal_in_special() {
  local addr
  addr=$(get_terminal_address)
  [ -n "$addr" ] && hyprctl clients -j | jq -e --arg ADDR "$addr" \
    'any(.[]; .address == $ADDR and .workspace.name == "special:scratchpad")' >/dev/null 2>&1
}

spawn_terminal() {
  debug_echo "Creating new dropdown terminal: $TERMINAL_CMD"

  local pos_info
  pos_info=$(calculate_dropdown_position)
  local target_x target_y width height monitor_name
  target_x=$(echo $pos_info | cut -d' ' -f1)
  target_y=$(echo $pos_info | cut -d' ' -f2)
  width=$(echo $pos_info | cut -d' ' -f3)
  height=$(echo $pos_info | cut -d' ' -f4)
  monitor_name=$(echo $pos_info | cut -d' ' -f5)

  local windows_before
  windows_before=$(hyprctl clients -j)
  local count_before
  count_before=$(echo "$windows_before" | jq 'length')

  # Spawn directly into scratchpad, hidden (silent)
  hyprctl dispatch exec "[float; size $width $height; workspace special:scratchpad silent] $TERMINAL_CMD"

  # Wait longer on 0.54.1 — kitty/foot need the extra time to map
  sleep 0.4

  local windows_after
  windows_after=$(hyprctl clients -j)
  local new_addr=""

  local count_after
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
    echo "$new_addr $monitor_name" >"$ADDR_FILE"
    debug_echo "Spawned: $new_addr on monitor $monitor_name"

    # FIX 0.54.1: move to workspace first, then pin, then animate.
    # Doing pin before the workspace move caused the bounce.
    sleep 0.15
    hyprctl dispatch movetoworkspacesilent "$CURRENT_WS,address:$new_addr"
    sleep 0.08
    hyprctl dispatch pin "address:$new_addr"
    sleep 0.05

    hyprctl dispatch resizewindowpixel "exact $width $height,address:$new_addr"
    animate_slide_down "$new_addr" "$target_x" "$target_y" "$width" "$height"
    return 0
  fi

  debug_echo "Failed to capture terminal address"
  return 1
}

# ── MAIN ──────────────────────────────────────────────────────────────────────
if terminal_exists; then
  TERMINAL_ADDR=$(get_terminal_address)
  debug_echo "Existing terminal: $TERMINAL_ADDR"

  focused_monitor=$(get_monitor_info | awk '{print $6}')
  dropdown_monitor=$(get_terminal_monitor)

  if [ "$focused_monitor" != "$dropdown_monitor" ]; then
    debug_echo "Monitor changed → relocating to $focused_monitor"
    pos_info=""
    pos_info=$(calculate_dropdown_position)
    target_x=$(echo $pos_info | cut -d' ' -f1)
    target_y=$(echo $pos_info | cut -d' ' -f2)
    width=$(echo $pos_info | cut -d' ' -f3)
    height=$(echo $pos_info | cut -d' ' -f4)
    monitor_name=$(echo $pos_info | cut -d' ' -f5)
    hyprctl dispatch movewindowpixel "exact $target_x $target_y,address:$TERMINAL_ADDR"
    hyprctl dispatch resizewindowpixel "exact $width $height,address:$TERMINAL_ADDR"
    echo "$TERMINAL_ADDR $monitor_name" >"$ADDR_FILE"
  fi

  if terminal_in_special; then
    debug_echo "Showing terminal (scratchpad → current ws)"

    pos_info=$(calculate_dropdown_position)
    target_x=$(echo $pos_info | cut -d' ' -f1)
    target_y=$(echo $pos_info | cut -d' ' -f2)
    width=$(echo $pos_info | cut -d' ' -f3)
    height=$(echo $pos_info | cut -d' ' -f4)

    # FIX 0.54.1: workspace first → pin → resize → animate (strict order)
    hyprctl dispatch movetoworkspacesilent "$CURRENT_WS,address:$TERMINAL_ADDR"
    sleep 0.08
    hyprctl dispatch pin "address:$TERMINAL_ADDR"
    sleep 0.05
    hyprctl dispatch resizewindowpixel "exact $width $height,address:$TERMINAL_ADDR"
    animate_slide_down "$TERMINAL_ADDR" "$target_x" "$target_y" "$width" "$height"
    hyprctl dispatch focuswindow "address:$TERMINAL_ADDR"

  else
    debug_echo "Hiding terminal (current ws → scratchpad)"

    geometry=$(get_window_geometry "$TERMINAL_ADDR")
    if [ -n "$geometry" ]; then
      curr_x=$(echo $geometry | cut -d' ' -f1)
      curr_y=$(echo $geometry | cut -d' ' -f2)
      curr_width=$(echo $geometry | cut -d' ' -f3)
      curr_height=$(echo $geometry | cut -d' ' -f4)

      debug_echo "Geometry: ${curr_x},${curr_y} ${curr_width}x${curr_height}"

      # Animate up (stops just before fully off-screen to avoid the 0.54.1
      # compositor snap-back that caused the brief reappearance flash)
      animate_slide_up "$TERMINAL_ADDR" "$curr_x" "$curr_y" "$curr_width" "$curr_height"

      # FIX 0.54.1: unpin BEFORE movetoworkspacesilent — reversed order from
      # the original. Unpinning after the move caused the 0.5 s ghost flash.
      hyprctl dispatch pin "address:$TERMINAL_ADDR"   # toggle off
      sleep 0.05
      hyprctl dispatch movetoworkspacesilent "$SPECIAL_WS,address:$TERMINAL_ADDR"
    else
      debug_echo "No geometry — hiding without animation"
      hyprctl dispatch pin "address:$TERMINAL_ADDR"
      sleep 0.05
      hyprctl dispatch movetoworkspacesilent "$SPECIAL_WS,address:$TERMINAL_ADDR"
    fi
  fi

else
  debug_echo "No terminal found — spawning"
  if spawn_terminal; then
    TERMINAL_ADDR=$(get_terminal_address)
    [ -n "$TERMINAL_ADDR" ] && hyprctl dispatch focuswindow "address:$TERMINAL_ADDR"
  fi
fi
