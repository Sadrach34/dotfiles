#!/usr/bin/env python3
"""Lee archivos .desktop y devuelve JSON para AppLauncher."""
import os, json, glob, re, subprocess

# ── Resolver nombre de icono a ruta de archivo ──────────────────────────────
_icon_cache: dict[str, str] = {}

def _gtk_theme() -> str:
    """Lee el tema de iconos GTK configurado."""
    for path in [
        os.path.expanduser("~/.config/gtk-3.0/settings.ini"),
        os.path.expanduser("~/.gtkrc-2.0"),
    ]:
        try:
            with open(path) as f:
                for line in f:
                    if "icon-theme-name" in line or "gtk-icon-theme" in line:
                        return line.split("=", 1)[1].strip().strip('"').strip("'")
        except Exception:
            pass
    return "hicolor"

GTK_THEME = _gtk_theme()

ICON_SIZES  = [
    "scalable", "256x256", "128x128", "64x64", "48x48",
    "32x32", "24x24", "22x22", "16x16", "192x192", "512x512",
]
ICON_EXTS   = [".svg", ".svgz", ".png", ".xpm"]
ICON_SUBDIRS = ["apps", "categories", "devices", "mimetypes", "status", "places", ""]
ICON_DIRS   = [
    os.path.expanduser(f"~/.local/share/icons/{GTK_THEME}"),
    os.path.expanduser("~/.local/share/icons/hicolor"),
    f"/usr/share/icons/{GTK_THEME}",
    "/usr/share/icons/hicolor",
    "/usr/share/icons/breeze",
    "/usr/share/pixmaps",
    os.path.expanduser("~/.local/share/icons"),
]

def resolve_icon(name: str) -> str:
    """Devuelve ruta absoluta al icono o '' si no se encuentra."""
    if not name:
        return ""
    if name.startswith("/"):
        return name if os.path.exists(name) else ""
    if name in _icon_cache:
        return _icon_cache[name]
    # 1) Buscar en directorios de iconos con estructura size/subdir/name.ext
    for base in ICON_DIRS:
        for size in ICON_SIZES:
            for sub in ICON_SUBDIRS:
                parts = [base, size, sub, name] if sub else [base, size, name]
                stem = os.path.join(*parts)
                for ext in ICON_EXTS:
                    p = stem + ext
                    if os.path.exists(p):
                        _icon_cache[name] = p
                        return p
        # 2) Directo en base/name.ext (para /usr/share/pixmaps)
        for ext in ICON_EXTS:
            p = os.path.join(base, name + ext)
            if os.path.exists(p):
                _icon_cache[name] = p
                return p
    # 3) Fallback: glob recursivo en /usr/share/icons y ~/.local/share/icons
    for search_base in ["/usr/share/icons", os.path.expanduser("~/.local/share/icons")]:
        for ext in ICON_EXTS:
            hits = glob.glob(os.path.join(search_base, "**", name + ext), recursive=True)
            if hits:
                # Preferir rutas con apps/ o 48x48
                hits.sort(key=lambda p: (
                    0 if "apps" in p else 1,
                    0 if "48x48" in p or "scalable" in p else 1,
                ))
                _icon_cache[name] = hits[0]
                return hits[0]
    _icon_cache[name] = ""
    return ""

DESKTOP_DIRS = [
    "/usr/share/applications",
    os.path.expanduser("~/.local/share/applications"),
]
CACHE_FILE = os.path.expanduser("~/.cache/quickshell/apps.json")

# ── Caché: solo reescanear si algún .desktop cambió ─────────────────────────
def _newest_mtime() -> float:
    """Devuelve el mtime más reciente entre todos los .desktop files."""
    mt = 0.0
    for d in DESKTOP_DIRS:
        for p in glob.glob(os.path.join(d, "*.desktop")):
            try:
                mt = max(mt, os.path.getmtime(p))
            except OSError:
                pass
    return mt

def _load_cache():
    try:
        cache_mtime = os.path.getmtime(CACHE_FILE)
        if cache_mtime >= _newest_mtime():
            with open(CACHE_FILE) as f:
                return json.load(f)
    except Exception:
        pass
    return None

def _save_cache(data):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, "w") as f:
            json.dump(data, f)
    except Exception:
        pass

# Intentar devolver desde caché
cached = _load_cache()
if cached is not None:
    print(json.dumps(cached))
    raise SystemExit(0)

# ── Escaneo completo ─────────────────────────────────────────────────────────
apps = []
seen = set()

for d in DESKTOP_DIRS:
    for path in sorted(glob.glob(os.path.join(d, "*.desktop"))):
        try:
            props = {}
            in_main = False
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if line == "[Desktop Entry]":
                        in_main = True
                    elif line.startswith("[") and in_main:
                        break
                    if not in_main or "=" not in line:
                        continue
                    k, _, v = line.partition("=")
                    k = k.strip()
                    if k not in props:
                        props[k] = v.strip()

            if props.get("NoDisplay", "").lower() == "true":
                continue
            if props.get("Hidden", "").lower() == "true":
                continue
            if props.get("Type", "") != "Application":
                continue

            name = props.get("Name", "")
            exec_cmd = props.get("Exec", "")
            if not name or not exec_cmd:
                continue
            if name in seen:
                continue
            seen.add(name)

            exec_clean = re.sub(r"\s*%[a-zA-Z]", "", exec_cmd).strip()
            terminal = props.get("Terminal", "").lower() == "true"
            display_name = props.get("GenericName", "") or props.get("Comment", "")
            apps.append({
                "name": name,
                "exec": exec_clean,
                "iconPath": resolve_icon(props.get("Icon", "")),
                "categories": props.get("Categories", ""),
                "terminal": terminal,
                "displayName": display_name,
            })
        except Exception:
            continue

apps.sort(key=lambda x: x["name"].lower())
_save_cache(apps)
print(json.dumps(apps))
