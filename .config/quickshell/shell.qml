import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects
import "./components"
import "./components/skwd-wall/qml" as SkwdTheme
import "./screenshot"

// Raíz del shell — punto de entrada de toda la configuración de Quickshell.
// Cada componente instanciado aquí crea una ventana/layer independiente en Wayland.
ShellRoot {
    id: root

    // Cargar Phosphor de forma explícita para que Qt lo encuentre por nombre en todos los módulos
    FontLoader { source: "/usr/share/fonts/TTF/Phosphor-Bold.ttf" }
    FontLoader { source: "/usr/share/fonts/TTF/Phosphor.ttf" }

    // Ruta base de la configuración (usada por subcomponentes para leer archivos)
    property string configPath: Quickshell.env("HOME") + "/.config/quickshell"

    SkwdTheme.Colors {
        id: skwdColors
    }

    // ── Flags de visibilidad globales ────────────────────────────────────────
    // Cada panel lee su flag para saber si debe mostrarse u ocultarse.
    // Los IpcHandlers de abajo los toggean desde keybinds de Hyprland.
    property bool dashboardVisible:       false  // sidebar derecho (stats, música, reloj…)
    property bool topPanelVisible:        false  // panel superior (notas, mezclador de audio)
    property bool appLauncherVisible:     false  // lanzador de apps con búsqueda y freq
    property bool windowSwitcherVisible:  false  // ALT+TAB estilo paralelo
    property bool wallpaperPickerVisible: false  // selector visual de fondos de pantalla
    property bool configPanelVisible:     false  // panel de configuración (apps/iconos/background)

    // ── Helpers de toggle ────────────────────────────────────────────────────
    // Llamados desde los IpcHandlers; invierten el flag correspondiente.
    function toggleDashboard()       { dashboardVisible      = !dashboardVisible }
    function toggleTopPanel()        { topPanelVisible       = !topPanelVisible }
    function toggleAppLauncher()     { appLauncherVisible    = !appLauncherVisible }
    function toggleWindowSwitcher()  { windowSwitcherVisible = !windowSwitcherVisible }
    function toggleWallpaperPicker() { wallpaperPickerVisible = !wallpaperPickerVisible }
    function toggleConfigPanel()     { configPanelVisible = !configPanelVisible }
    function openWallpaperPicker()   { wallpaperPickerVisible = true }
    function closeWallpaperPicker()  { wallpaperPickerVisible = false }

    // ── Componentes (cada uno es una PanelWindow o similar en Wayland) ───────

    Dashboard {}           // Sidebar derecho: perfil, power bar, música, notificaciones,
                           //   volumen global, CPU/RAM/disco, reloj y calendario

    TopPanel {}            // Panel que baja desde arriba: editor de notas markdown
                           //   + mezclador de volumen por app (faders verticales)

    NotificationToast {}   // Toast flotante esquina superior derecha: muestra cada
                           //   notificación entrante; click abre swappy si es captura

    ClickOverlay {}        // Capa transparente que captura clics fuera de cualquier
                           //   panel abierto para cerrarlo (dismiss on outside click)

    AppLauncher {
        colors: skwdColors
    }         // Lanzador de apps: búsqueda, ranking por frecuencia,
                           //   filtro Steam, soporte de apps de terminal, watcher
                           //   inotifywait para refrescar al instalar/desinstalar apps

    WindowSwitcher {
        colors: skwdColors
    }      // Switcher de ventanas: vista en parallelogram-slices,
                           //   badge FLOAT, cerrar ventana con Del, multi-monitor

    WallpaperPicker {}     // Selector de fondos: thumbnails 900×520, navegación
                           //   con teclado/scroll, aplica con swww

    ConfigPanel {
        colors: skwdColors
    }

    ModernClock {}

    // ── IPC Handlers ─────────────────────────────────────────────────────────
    // Exponen comandos que Hyprland puede llamar con:
    //   qs ipc call <target> <function>
    // Ejemplo en hyprland.conf:  bind = SUPER, D, exec, qs ipc call dashboard toggle

    IpcHandler {
        target: "dashboard"
        function toggle() { root.toggleDashboard() }
    }
    IpcHandler {
        target: "toppanel"
        function toggle() { root.toggleTopPanel() }
    }
    IpcHandler {
        target: "applauncher"
        function toggle() { root.toggleAppLauncher() }
    }
    IpcHandler {
        target: "windowswitcher"
        function toggle() { root.toggleWindowSwitcher() }
    }
    IpcHandler {
        target: "wallpaperpicker"
        function toggle() { root.toggleWallpaperPicker() }
        function open() { root.openWallpaperPicker() }
        function close() { root.closeWallpaperPicker() }
    }
    IpcHandler {
        target: "config"
        function toggle() { root.toggleConfigPanel() }
    }

    // ── Screenshot tool (Win+S) ───────────────────────────────────────────────
    // ScreenshotTool se crea al activarse y se destruye al cerrar (active: SsState.screenshotToolVisible)
    // ScreenshotOverlay siempre cargado para recibir la señal onImageSaved
    Variants {
        model: Quickshell.screens
        Loader {
            id: screenshotToolLoader
            active: SsState.screenshotToolVisible
            required property ShellScreen modelData
            sourceComponent: ScreenshotTool {
                targetScreen: screenshotToolLoader.modelData
            }
        }
    }

    Variants {
        model: Quickshell.screens
        Loader {
            id: screenshotOverlayLoader
            active: true
            required property ShellScreen modelData
            sourceComponent: ScreenshotOverlay {
                targetScreen: screenshotOverlayLoader.modelData
            }
        }
    }

    IpcHandler {
        target: "screenshot"
        function toggle() { SsState.screenshotToolVisible = !SsState.screenshotToolVisible }
    }

    // ── Grabación de pantalla (Win+R) ─────────────────────────────────────────
    // ScreenrecordTool siempre cargado; open()/close() se llaman por IPC.
    Loader {
        id: screenRecordLoader
        active: true
        source: "./screenshot/ScreenrecordTool.qml"

        Connections {
            target: SsState
            function onScreenRecordToolVisibleChanged() {
                if (screenRecordLoader.status === Loader.Ready) {
                    if (SsState.screenRecordToolVisible) {
                        screenRecordLoader.item.open();
                    } else {
                        screenRecordLoader.item.close();
                    }
                }
            }
        }

        Connections {
            target: screenRecordLoader.item
            ignoreUnknownSignals: true
            function onVisibleChanged() {
                if (screenRecordLoader.item && !screenRecordLoader.item.visible && SsState.screenRecordToolVisible) {
                    SsState.screenRecordToolVisible = false;
                }
            }
        }
    }

    IpcHandler {
        target: "screenrecord"
        function toggle() { SsState.screenRecordToolVisible = !SsState.screenRecordToolVisible }
    }

    // ── Indicador de grabación activa ─────────────────────────────────────────
    // Aparece en esquina superior-derecha mientras ScreenRecorder.isRecording
    Variants {
        model: Quickshell.screens
        Loader {
            id: recordingIndicatorLoader
            required property ShellScreen modelData
            // Solo en la primera pantalla para no duplicar
            active: modelData === Quickshell.screens[0]
            sourceComponent: RecordingIndicator {
                targetScreen: recordingIndicatorLoader.modelData
            }
        }
    }
}