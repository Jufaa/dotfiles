#!/usr/bin/env bash
#
# Arch + Hyprland environment bootstrap.
#
# Reproduces this setup on a fresh Arch install: packages, AUR packages,
# oh-my-zsh, wallpapers and every config under home/ (linked with GNU stow).
#
# Usage:
#   ./install.sh                  full run
#   ./install.sh --no-packages    only link configs
#   ./install.sh --no-wallpapers  skip the wallpaper downloads (~5 GB)
#   ./install.sh --dry-run        print what would happen, change nothing
#
# Note: this script intentionally uses POSIX `find` instead of `fd`, because it
# must run on a bare Arch install before any extra tooling exists.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

DO_PACKAGES=1
DO_WALLPAPERS=1
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --no-packages)   DO_PACKAGES=0 ;;
    --no-wallpapers) DO_WALLPAPERS=0 ;;
    --dry-run)       DRY_RUN=1 ;;
    -h|--help)       sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- output ----

C_RESET=$'\033[0m'; C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'

step() { printf '\n%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf '  %s✔%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '\n%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  %s[dry-run]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
  else
    "$@"
  fi
}

# --------------------------------------------------------------- prechecks --

step "Checking the system"

command -v pacman >/dev/null || die "this script only runs on Arch or an Arch derivative."
[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not as root. sudo is called where needed."
command -v sudo >/dev/null || die "sudo is not installed."

ok "Arch detected, running as $(whoami)"

# Ask for sudo once and keep the timestamp alive for the whole run.
if [ "$DRY_RUN" -eq 0 ]; then
  sudo -v || die "sudo authentication failed."
  while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
fi

# --------------------------------------------------------------- packages ---

install_yay() {
  command -v yay >/dev/null && { ok "yay already installed"; return; }
  step "Installing yay (AUR helper)"
  local tmp
  tmp="$(mktemp -d)"
  run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  if [ "$DRY_RUN" -eq 0 ]; then
    ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
  fi
  rm -rf "$tmp"
  ok "yay installed"
}

install_packages() {
  step "Installing base tooling"
  run sudo pacman -S --needed --noconfirm git stow rsync base-devel

  install_yay

  step "Installing official repository packages"
  # --needed skips anything already present; missing names are reported but do
  # not abort the run, since package names drift between Arch releases.
  if [ "$DRY_RUN" -eq 0 ]; then
    mapfile -t pkgs < <(grep -v '^\s*\(#\|$\)' "$DOTFILES/packages/pacman.txt")
    sudo pacman -S --needed --noconfirm "${pkgs[@]}" || warn "some packages failed; check the output above"
  else
    run sudo pacman -S --needed --noconfirm "from packages/pacman.txt"
  fi

  step "Installing AUR packages"
  if [ "$DRY_RUN" -eq 0 ]; then
    mapfile -t aur < <(grep -v '^\s*\(#\|$\)' "$DOTFILES/packages/aur.txt")
    yay -S --needed --noconfirm "${aur[@]}" || warn "some AUR packages failed; check the output above"
  else
    run yay -S --needed --noconfirm "from packages/aur.txt"
  fi

  warn "packages/hardware.txt is NOT installed automatically — it holds the kernel,"
  warn "microcode and GPU drivers of the source machine. Review it and install by hand."
}

# --------------------------------------------------------------- oh-my-zsh --

install_omz() {
  step "Setting up zsh"

  local omz="$HOME/.oh-my-zsh"
  if [ -d "$omz" ]; then
    ok "oh-my-zsh already installed"
  else
    run git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$omz"
    ok "oh-my-zsh installed"
  fi

  local custom="$omz/custom/plugins"
  run mkdir -p "$custom"

  local name url
  while read -r name url; do
    if [ -d "$custom/$name" ]; then
      ok "plugin $name already present"
    else
      run git clone --depth 1 "$url" "$custom/$name"
      ok "plugin $name installed"
    fi
  done <<'PLUGINS'
zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
PLUGINS

  if [ "$SHELL" != "$(command -v zsh)" ]; then
    run chsh -s "$(command -v zsh)"
    ok "default shell set to zsh (takes effect on next login)"
  else
    ok "zsh is already the default shell"
  fi
}

# -------------------------------------------------------------- wallpapers --

install_wallpapers() {
  step "Downloading wallpapers"
  warn "this pulls roughly 5 GB; skip it with --no-wallpapers"

  run mkdir -p "$HOME/Pictures"

  local name url
  while read -r name url; do
    if [ -d "$HOME/Pictures/$name" ]; then
      ok "$name already present"
    else
      run git clone --depth 1 "$url" "$HOME/Pictures/$name"
      ok "$name downloaded"
    fi
  done <<'WALLPAPERS'
lwalpapers https://github.com/whoisYoges/lwalpapers.git
wallpapers https://github.com/JaKooLit/Wallpaper-Bank.git
WALLPAPERS
}

# ------------------------------------------------------------------- stow ---

# Move anything that would collide with a stow link into the backup directory,
# so the run never destroys an existing config and never fails halfway through.
backup_conflicts() {
  local pkg_dir="$1" rel target
  while IFS= read -r rel; do
    target="$HOME/$rel"
    [ -e "$target" ] || [ -L "$target" ] || continue
    # An existing link that already points inside this repo is ours: leave it.
    if [ -L "$target" ] && [[ "$(readlink -f "$target")" == "$DOTFILES"/* ]]; then
      continue
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '  %s[dry-run]%s backup %s\n' "$C_YELLOW" "$C_RESET" "$rel"
    else
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$target" "$BACKUP/$rel"
    fi
  done < <(cd "$pkg_dir" && find . \( -type f -o -type l \) -printf '%P\n')
}

link_configs() {
  step "Linking configs with stow"

  command -v stow >/dev/null || die "stow is not installed; run without --no-packages first."

  run mkdir -p "$HOME/.config"

  local pkg
  for pkg in "$DOTFILES"/home/*/; do
    pkg="$(basename "$pkg")"
    backup_conflicts "$DOTFILES/home/$pkg"
    run stow --dir "$DOTFILES/home" --target "$HOME" --restow "$pkg"
    ok "$pkg"
  done

  if [ -d "$BACKUP" ]; then
    warn "previous configs were moved to $BACKUP"
  fi
}

# --------------------------------------------------------------- services ---

enable_services() {
  step "Enabling services"

  local svc
  for svc in NetworkManager bluetooth sddm; do
    if systemctl list-unit-files "$svc.service" >/dev/null 2>&1; then
      run sudo systemctl enable "$svc.service"
      ok "$svc enabled"
    else
      warn "$svc is not installed, skipped"
    fi
  done
}

# ------------------------------------------------------------------- main ---

if [ "$DO_PACKAGES" -eq 1 ]; then
  install_packages
  install_omz
fi

if [ "$DO_WALLPAPERS" -eq 1 ]; then
  install_wallpapers
fi

link_configs

if [ "$DO_PACKAGES" -eq 1 ]; then
  enable_services
fi

step "Done"
cat <<'EOF'

Remaining manual steps:

  1. Review packages/hardware.txt and install the drivers your machine needs
     (Intel / AMD / NVIDIA microcode and GPU drivers differ per machine).
  2. Edit ~/.config/hypr/monitors.conf — monitor layout is machine specific.
  3. Log out and back in so zsh and SDDM take effect.

EOF
