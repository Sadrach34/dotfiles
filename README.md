<div align="center">
  
```
  ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
  ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
  ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
  ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
  ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
  ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
```

# sadrach34 / Dotfiles

**Hyprland · Arch Linux** — configuración personal para uso real, no para demos.

![](https://img.shields.io/github/last-commit/Sadrach34/dotfiles?style=for-the-badge&color=cba6f7&labelColor=1e1e2e&logo=git&logoColor=cdd6f4)
![](https://img.shields.io/github/stars/Sadrach34/dotfiles?style=for-the-badge&color=f38ba8&labelColor=1e1e2e&logo=starship&logoColor=cdd6f4)
![](https://img.shields.io/github/repo-size/Sadrach34/dotfiles?style=for-the-badge&color=a6e3a1&labelColor=1e1e2e&logo=files&logoColor=cdd6f4)

</div>

---

<div align="center">
  <h2>· capturas ·</h2>
</div>

### Escritorio principal

![Desktop](./assets/screenshots/desktop-main.png)

### Top panel & Dashboard

<table>
<tr>
<td><img src="./assets/screenshots/top_panel1.png"/></td>
<td><img src="./assets/screenshots/top_panel2.png"/></td>
<td><img src="./assets/screenshots/top_panel3.png"/></td>
</tr>
<tr>
<td><img src="./assets/screenshots/top_panel4.png"/></td>
<td><img src="./assets/screenshots/top_panel5.png"/></td>
<td><img src="./assets/screenshots/dashboard.png"/></td>
</tr>
</table>

### App launcher & Wallpaper picker

| App launcher | App selector | Wallpaper picker |
|:---:|:---:|:---:|
| ![](./assets/screenshots/app_launcher.png) | ![](./assets/screenshots/app_selector.png) | ![](./assets/screenshots/wallpaper-picker.png) |

---

<div align="center">
  <h2>· qué incluye ·</h2>
</div>

<details open>
<summary><b>Componentes principales</b></summary>
<br>

| Componente | Stack | Descripción |
|---|---|---|
| **Hyprland** | compositor | Keybinds, scripts, autostart y gestión de wallpapers |
| **Quickshell** | widgets | Top panel, dashboard, launcher, wallpaper picker y reloj personalizado |
| **Waybar** | barra | Módulos extra con integración a Quickshell |
| **Zsh** | shell | `.zshrc` con aliases y configuración de uso diario |
| **install.sh** | tooling | Script con modos `--install` y `--update`, con backup automático |
| **wallpapers/** | assets | Colección de fondos estáticos curada |

</details>

<details>
<summary><b>Formatos de wallpaper soportados</b></summary>
<br>

Solo se incluyen wallpapers **estáticos** para garantizar compatibilidad con todos los backends.

✅ **Soportados:** `.jpg` `.jpeg` `.png` `.webp` `.bmp` `.tiff` `.pnm` `.tga` `.farbfeld`

❌ **Excluidos:** `.gif` `.mp4` `.mkv` `.mov` `.webm` `.avi`

</details>

---

<div align="center">
  <h2>· instalación ·</h2>
</div>

### Primera instalación

```bash
git clone https://github.com/Sadrach34/dotfiles.git
cd dotfiles
bash install.sh --install
```

### Actualizar dotfiles existentes

```bash
cd dotfiles
bash install.sh --update
```

### Modo automático (detecta instalación o update)

```bash
bash install.sh
```

> El script detecta si ya existe una instalación previa y hace **backup automático** de los archivos antes de sobrescribir.

---

<div align="center">
  <h2>· estructura ·</h2>
</div>

```
dotfiles/
├── .config/
│   ├── hypr/          # compositor — keybinds, monitors, scripts
│   ├── quickshell/    # widgets — panel, dashboard, launcher, clock
│   └── waybar/        # barra — módulos e integración con QS
├── wallpapers/        # fondos estáticos
├── assets/            # capturas de pantalla y recursos del repo
├── .zshrc             # shell — aliases y configuración Zsh
└── install.sh         # instalador con backup automático
```

---

<div align="center">
  <h2>· créditos ·</h2>
</div>

Repo mantenido por [`sadrach34`](https://github.com/Sadrach34).  
Proyectos y personas que sirvieron de inspiración o referencia:

- **[JaKooLit](https://github.com/JaKooLit)** — estructura y scripting de Hyprland
- **[ambxst](https://github.com/Axenide)** — estética y layout de Quickshell
- **[Skewed / liixini](https://github.com/liixini)** — diseño de appselector y applauncher
- **[Modern-Clock-for-Quickshell — Xinoxi](https://github.com/Xinoxi)** — componente del reloj

---

## Licencia

Este repositorio se distribuye bajo **GNU General Public License v3.0 (GPLv3)**.

- El texto completo de la licencia está en `LICENSE`.
- Los archivos derivados de otros proyectos conservan sus atribuciones en cabeceras/comentarios.
- El detalle de licencias y avisos de terceros está en `THIRD_PARTY_LICENSES.md` y `NOTICE-DERIVATIVES.md`.
- Las modificaciones locales se distribuyen bajo GPLv3 junto con el resto del repositorio.
