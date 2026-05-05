<div align="center">
  
```
                                  ███████╗██████╗ ██████╗ ██╗  ██╗
                                  ██╔════╝██╔══██╗██╔══██╗╚██╗██╔╝
                                  ███████╗██║  ██║██████╔╝ ╚███╔╝ 
                                  ╚════██║██║  ██║██╔══██╗ ██╔██╗ 
                                  ███████║██████╔╝██║  ██║██╔╝ ██╗
                                  ╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
```

# sadrach34 / SdrxDots

**Hyprland · Arch Linux** — personal configuration for real-world use.

![](https://img.shields.io/github/last-commit/Sadrach34/SdrxDots?style=for-the-badge&color=cba6f7&labelColor=1e1e2e&logo=git&logoColor=cdd6f4)
![](https://img.shields.io/github/stars/Sadrach34/SdrxDots?style=for-the-badge&color=f38ba8&labelColor=1e1e2e&logo=starship&logoColor=cdd6f4)
![](https://img.shields.io/github/repo-size/Sadrach34/SdrxDots?style=for-the-badge&color=a6e3a1&labelColor=1e1e2e&logo=files&logoColor=cdd6f4)

</div>

---

<div align="center">
  <h2>· screenshots ·</h2>
</div>

### Main desktop

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

|                App launcher                |                App selector                |                Wallpaper picker                |
| :----------------------------------------: | :----------------------------------------: | :--------------------------------------------: |
| ![](./assets/screenshots/app_launcher.png) | ![](./assets/screenshots/app_selector.png) | ![](./assets/screenshots/wallpaper-picker.png) |

---

<div align="center">
  <h2>· what's included ·</h2>
</div>

<details open>
<summary><b>Main components</b></summary>
<br>

| Component       | Stack      | Description                                                        |
| --------------- | ---------- | ------------------------------------------------------------------ |
| **Hyprland**    | compositor | Keybinds, scripts, autostart, and wallpaper management             |
| **Quickshell**  | widgets    | Top panel, dashboard, launcher, wallpaper picker, and custom clock |
| **Waybar**      | bar        | Extra modules with Quickshell integration                          |
| **Zsh**         | shell      | `.zshrc` with aliases and daily-use configuration                  |
| **install.sh**  | tooling    | Script with `--install` and `--update` modes, with auto-backup     |
| **wallpapers/** | assets     | Curated collection of static wallpapers                            |

</details>

<details>
<summary><b>Supported wallpaper formats</b></summary>
<br>

Only **static** wallpapers are included to ensure compatibility with all backends.

✅ **Supported:** `.jpg` `.jpeg` `.png` `.webp` `.bmp` `.tiff` `.pnm` `.tga` `.farbfeld`

❌ **Excluded:** `.gif` `.mp4` `.mkv` `.mov` `.webm` `.avi`

</details>

---

<div align="center">
  <h2>· documentation & wiki ·</h2>
</div>

For detailed documentation, installation guides, and component information in your language, visit the **[SdrxDots Wiki](https://github.com/Sadrach34/SdrxDots/wiki)**.

**Available languages:**

- 🇬🇧 **English** — [Home](https://github.com/Sadrach34/SdrxDots/wiki/Home-en) · [Installation](https://github.com/Sadrach34/SdrxDots/wiki/Installation-en) · [Components](https://github.com/Sadrach34/SdrxDots/wiki/Components-en)
- 🇪🇸 **Español** — [Inicio](https://github.com/Sadrach34/SdrxDots/wiki/Home-es) · [Instalación](https://github.com/Sadrach34/SdrxDots/wiki/Installation-es) · [Componentes](https://github.com/Sadrach34/SdrxDots/wiki/Components-es)
- 🇮🇳 **हिन्दी** — [गृह](https://github.com/Sadrach34/SdrxDots/wiki/Home-hi) · [स्थापना](https://github.com/Sadrach34/SdrxDots/wiki/Installation-hi) · [घटकों](https://github.com/Sadrach34/SdrxDots/wiki/Components-hi)
- 🇨🇳 **中文 (简体)** — [主页](https://github.com/Sadrach34/SdrxDots/wiki/Home-zh) · [安装](https://github.com/Sadrach34/SdrxDots/wiki/Installation-zh) · [组件](https://github.com/Sadrach34/SdrxDots/wiki/Components-zh)
- 🇷🇺 **Русский** — [Главная](https://github.com/Sadrach34/SdrxDots/wiki/Home-ru) · [Установка](https://github.com/Sadrach34/SdrxDots/wiki/Installation-ru) · [Компоненты](https://github.com/Sadrach34/SdrxDots/wiki/Components-ru)

---

<div align="center">
  <h2>· installation ·</h2>
</div>

### First installation

```bash
git clone https://github.com/Sadrach34/SdrxDots.git
cd SdrxDots
bash install.sh --install
```

### Custom installation (examples)

```bash
# Full setup with SDDM/GRUB, laptop profile, animations, and gamer/dev stack
bash install.sh --install --sddm --grub --laptop --animations --gamer --programmer

# Minimal desktop setup (without animations or gamer)
bash install.sh --install --no-animations --no-gamer --programmer
```

### Update existing SdrxDots

```bash
cd SdrxDots
bash install.sh --update
```

### Update with Sdrx command (from zsh)

The base `.zshrc` includes the `Sdrx` command, which runs `install.sh` with the same module options.

```bash
# update (default)
Sdrx

# update with explicit modules
Sdrx --sddm --grub --laptop

# initial installation
Sdrx --install --animations --gamer --programmer

# help
Sdrx --help
```

### Update without re-prompting modules

In `--update` mode, the installer reuses options saved from the previous installation (`sddm/grub/laptop/animations/gamer/programmer`) and only applies changes.

You can force any module with explicit flags:

```bash
bash install.sh --update --sddm --grub --laptop
bash install.sh --update --no-sddm --no-grub --no-laptop
```

### System update script

`~/update.sh` is also installed. It checks for new changes in the remote GitHub repo and shows an available update notification before proceeding with package updates.

### Automatic mode (detects installation or update)

```bash
bash install.sh
```

> The script detects whether a previous installation exists and makes **automatic backups** before overwriting files.

---

<div align="center">
  <h2>· structure ·</h2>
</div>

```
SdrxDots/
├── .config/
│   ├── hypr/          # compositor — keybinds, monitors, scripts
│   ├── quickshell/    # widgets — panel, dashboard, launcher, clock
│   └── waybar/        # bar — modules and Quickshell integration
├── wallpapers/        # static wallpapers
├── assets/            # screenshots and repo resources
├── .zshrc             # shell — aliases and Zsh configuration
└── install.sh         # installer with automatic backup
```

---

<div align="center">
  <h2>· credits ·</h2>
</div>

Repository maintained by [sadrach34](https://github.com/Sadrach34).  
Projects and people that served as inspiration or reference:

- **[JaKooLit](https://github.com/JaKooLit)** — Hyprland structure and scripting
- **[ambxst](https://github.com/Axenide)** — Quickshell aesthetics and layout
- **[Skewed / liixini](https://github.com/liixini)** — appselector and applauncher design
- **[Modern-Clock-for-Quickshell — Xinoxi](https://github.com/Xinoxi)** — clock component

---


## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Sadrach34/SdrxDots&type=Date)](https://star-history.com/#Sadrach34/SdrxDots&Date)

## 🤝 Contribution

<div align="center">
  We welcome contributions of all kinds — bug fixes, new features, documentation improvements, and more.<br>
  Please read our <a href=".github/CONTRIBUTING.md"><strong>Contributing Guide</strong></a> before submitting a pull request.
</div>

<br>

<div align="center">
  We thank all our contributors for their valuable contributions.
</div>

<div align="center">
  <a href="https://github.com/Sadrach34/SdrxDots/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=Sadrach34/SdrxDots" style="border-radius: 15px; box-shadow: 0 0 20px rgba(0, 217, 255, 0.3);" />
  </a>
</div>

## License

This repository is distributed under **GNU General Public License v3.0 (GPLv3)**.

- The full license text is in LICENSE.
- Files derived from other projects keep their attributions in headers/comments.
- Third-party license details and notices are in .github/THIRD_PARTY_LICENSES.md and .github/NOTICE-DERIVATIVES.md.
- Local modifications are distributed under GPLv3 together with the rest of the repository.
