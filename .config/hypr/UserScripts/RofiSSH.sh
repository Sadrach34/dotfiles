#!/bin/bash
# /* ---- 🚀 Script de Control Total del Servidor por Rofi 🚀 ---- */

# ============================================
# CONFIGURACIÓN
# ============================================
# Tema de Rofi
rofi_theme="$HOME/.config/rofi/config-rofi-ssh.rasi"

# Datos del servidor (tu laptop)
SERVER_USER="sadrach"
SERVER_IP="192.168.1.50"
SERVER_PORT="22"
SERVER_NAME="Mi Laptop"

# Comando del servidor de Minecraft
MINECRAFT_SERVICE="minecraft.service"

# Explorador de archivos que usas en tu PC de escritorio (ej: thunar, nautilus, dolphin)
FILE_EXPLORER="thunar"

# ============================================
# FUNCIONES
# ============================================

# 1. Abrir una terminal con conexión SSH
open_ssh_terminal() {
  kitty ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_IP"
}

# 2. Enviar un comando al servidor sin abrir una terminal interactiva
send_ssh_command() {
  ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_IP" "$1"
}

# 3. Toggle del servidor de Minecraft (encender/apagar según estado actual)
toggle_minecraft_server() {
  # Verificar el estado actual del servicio
  status=$(send_ssh_command "systemctl is-active $MINECRAFT_SERVICE")
  
  if [ "$status" = "active" ]; then
    # Si está activo, apagarlo
    send_ssh_command "sudo systemctl stop $MINECRAFT_SERVICE"
    notify-send "🛑 Apagando servidor de Minecraft..."
  else
    # Si está inactivo, encenderlo
    send_ssh_command "sudo systemctl start $MINECRAFT_SERVICE"
    notify-send "🚀 Encendiendo servidor de Minecraft..."
  fi
}

# 4. Revisar el estado del servidor de Minecraft
check_minecraft_status() {
  # Ejecuta el comando y muestra la salida en una nueva ventana de kitty
  kitty --title "Estado del Servidor Minecraft" sh -c "ssh -p '$SERVER_PORT' '$SERVER_USER@$SERVER_IP' 'sudo systemctl status $MINECRAFT_SERVICE'; read"
}

# 5. Obtener el estado actual para el menú
get_minecraft_menu_option() {
  status=$(send_ssh_command "systemctl is-active $MINECRAFT_SERVICE" 2>/dev/null)
  
  if [ "$status" = "active" ]; then
    echo "🔴 Apagar Minecraft"
  else
    echo "🟢 Encender Minecraft"
  fi
}

# 6. Abrir la carpeta del servidor en el explorador de archivos local
open_sftp_folder() {
  $FILE_EXPLORER "sftp://$SERVER_USER@$SERVER_IP/home/$SERVER_USER/" &
  notify-send "📂 Abriendo carpeta del servidor..."
}

# 7. Abrir la carpeta del servidor en VS Code
open_vscode_remote() {
  code --remote ssh-remote+$SERVER_USER@$SERVER_IP "/home/$SERVER_USER/" &
  notify-send "🧑‍💻 Abriendo VS Code en el servidor..."
}

# 8. Toggle bot de Telegram de finanzas
toggle_telegram_bot() {
  # Verificar si el bot está corriendo
  bot_running=$(send_ssh_command "pgrep -f 'bot_main.py' > /dev/null && echo 'running' || echo 'stopped'")
  
  if [ "$bot_running" = "running" ]; then
    # Si está corriendo, apagarlo
    send_ssh_command "pkill -f 'bot_main.py' 2>/dev/null"
    notify-send "🛑 Cerrando bot de Telegram..."
  else
    # Si está detenido, iniciarlo
    send_ssh_command "pkill -f 'bot_main.py' 2>/dev/null"
    sleep 1
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_IP" "cd /home/sadrach/Bots/python_bot && nohup ./venv/bin/python bot_main.py > /dev/null 2>&1 &" &
    notify-send "🤖 Iniciando bot de Telegram (Finanzas)..."
  fi
}

# 9. Obtener el estado del bot de Telegram para el menú
get_telegram_bot_menu_option() {
  bot_running=$(send_ssh_command "pgrep -f 'bot_main.py' > /dev/null && echo 'running' || echo 'stopped'" 2>/dev/null)
  
  if [ "$bot_running" = "running" ]; then
    echo "🛑 Apagar Bot Telegram"
  else
    echo "🤖 Iniciar Bot Telegram"
  fi
}

# 10. Toggle del sistema POS
toggle_pos_script() {
  # Verificar si el POS está corriendo
  pos_running=$(send_ssh_command "pgrep -f 'iniciar_pos.sh\|flask' > /dev/null && echo 'running' || echo 'stopped'")
  
  if [ "$pos_running" = "running" ]; then
    # Si está corriendo, apagarlo
    send_ssh_command "bash /home/sadrach/Bots/python_bot/pagina_web/detener_pos.sh"
    notify-send "🛑 Cerrando sistema POS en el servidor..."
  else
    # Si está detenido, iniciarlo
    send_ssh_command "pkill -f 'iniciar_pos.sh' 2>/dev/null; pkill -f 'flask' 2>/dev/null"
    sleep 1
    ssh -p "$SERVER_PORT" "$SERVER_USER@$SERVER_IP" "nohup bash /home/sadrach/Bots/python_bot/pagina_web/iniciar_pos.sh > /dev/null 2>&1 &" &
    notify-send "🐍 Iniciando sistema POS en el servidor..."
    sleep 3 && xdg-open "http://$SERVER_IP:5000" &
  fi
}

# 11. Obtener el estado del POS para el menú
get_pos_menu_option() {
  pos_running=$(send_ssh_command "pgrep -f 'iniciar_pos.sh\|flask' > /dev/null && echo 'running' || echo 'stopped'" 2>/dev/null)
  
  if [ "$pos_running" = "running" ]; then
    echo "🛑 Apagar POS System"
  else
    echo "🐍 Iniciar POS System"
  fi
}


# ============================================
# MENÚ ROFI
# ============================================

# Obtener la opción dinámica de Minecraft según su estado
minecraft_option=$(get_minecraft_menu_option)

# Obtener la opción dinámica del Bot de Telegram según su estado
telegram_bot_option=$(get_telegram_bot_menu_option)

# Obtener la opción dinámica del POS según su estado
pos_option=$(get_pos_menu_option)

# Opciones del menú
options="$minecraft_option\n📊 Estado Minecraft\n📂 Abrir Carpeta (SFTP)\n🧑‍💻 Editar en VS Code\n🖥️  Conectar (Terminal)\n$telegram_bot_option\n$pos_option\n❌ Salir"

# Mostrar menú Rofi
user_choice=$(echo -e "$options" | rofi -dmenu -p "Control de Servidor ($SERVER_NAME)" -config "$rofi_theme")

# Procesar la elección del usuario
case "$user_choice" in
  "🟢 Encender Minecraft"|"🔴 Apagar Minecraft")
    toggle_minecraft_server
    ;;
  "📊 Estado Minecraft")
    check_minecraft_status
    ;;
  "📂 Abrir Carpeta (SFTP)")
    open_sftp_folder
    ;;
  "🧑‍💻 Editar en VS Code")
    open_vscode_remote
    ;;
  "🖥️  Conectar (Terminal)")
    open_ssh_terminal
    ;;
  "🤖 Iniciar Bot Telegram"|"🛑 Apagar Bot Telegram")
    toggle_telegram_bot
    ;;
  "🐍 Iniciar POS System"|"🛑 Apagar POS System")
    toggle_pos_script
    ;;
  *)
    exit 0
    ;;
esac