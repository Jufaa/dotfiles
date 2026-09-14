# dotfiles

Arch Linux + Hyprland environment, reproducible on a fresh install with one script.

## Install

```sh
git clone https://github.com/Jufaa/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Useful flags:

| Flag | Effect |
| --- | --- |
| `--dry-run` | Print every action without changing anything. Run this first. |
| `--no-packages` | Only link the configs, skip pacman / AUR / oh-my-zsh. |
| `--no-wallpapers` | Skip the wallpaper repositories (~5 GB). |

## What the script does

1. Installs `git`, `stow`, `rsync`, `base-devel`, then `yay` if missing.
2. Installs every package in `packages/pacman.txt` and `packages/aur.txt`.
3. Installs oh-my-zsh plus `zsh-autosuggestions` and `zsh-syntax-highlighting`,
   and sets zsh as the login shell.
4. Clones the wallpaper repositories into `~/Pictures`.
5. Links everything under `home/` into `$HOME` with GNU stow. Anything that
   would be overwritten is moved to `~/.dotfiles-backup/<timestamp>/` first.
6. Enables `NetworkManager`, `bluetooth` and `sddm`.

## Layout

```
dotfiles/
├── install.sh          bootstrap script
├── packages/
│   ├── pacman.txt      explicitly installed official packages
│   ├── aur.txt         AUR packages
│   └── hardware.txt    kernel, microcode and GPU drivers — NOT auto-installed
└── home/               one stow package per application
    ├── hypr/.config/hypr/
    ├── kitty/.config/kitty/
    ├── nvim/.config/nvim/
    ├── waybar/.config/waybar/
    ├── rofi/.config/rofi/
    ├── swaync/.config/swaync/
    ├── wlogout/.config/wlogout/
    ├── quickshell/.config/quickshell/
    ├── btop|cava|fastfetch/.config/…
    ├── gtk/.config/gtk-3.0|gtk-4.0/
    ├── qt/.config/Kvantum|qt5ct|qt6ct/
    ├── zed/.config/zed/
    ├── spicetify/.config/spicetify/
    └── zsh/.zshrc .zshenv .zprofile
```

Each directory under `home/` mirrors the path it takes inside `$HOME`, which is
what lets a single `stow` call place it correctly.

## Machine-specific pieces

These are deliberately **not** handled automatically, because they differ per
machine and getting them wrong leaves an unbootable or blank system:

- **`packages/hardware.txt`** — kernel, `intel-ucode`, and the Intel/AMD/Nouveau
  GPU drivers of the source machine. Review it and install what your hardware
  needs.
- **`home/hypr/.config/hypr/monitors.conf`** — monitor layout, resolution and
  refresh rate.
- **`~/.gitconfig` and credentials** — never stored here.

## Working on the configs

Once installed, every path in `~/.config` is a symlink into this repository, so
editing a config *is* editing the repo. Commit from `~/dotfiles`.

To add a new application:

```sh
mkdir -p home/<app>/.config/<app>
cp -a ~/.config/<app>/. home/<app>/.config/<app>/
stow --dir home --target "$HOME" --restow <app>
```

To refresh the package lists after installing something new:

```sh
pacman -Qqe | grep -vxFf packages/aur.txt | grep -vxFf packages/hardware.txt > packages/pacman.txt
pacman -Qqm > packages/aur.txt
```

## Credits

The Hyprland configuration is based on
[JaKooLit/Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots).
# dotfiles
