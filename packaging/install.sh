#!/usr/bin/env bash
#
# Ganbattea installer
#
# Installs the prebuilt binary, a start-menu entry and the icon.
# Run it from the extracted release folder:
#
#   ./install.sh                  install for the current user (~/.local)
#   ./install.sh --system         install for all users (/usr/local, uses sudo)
#   ./install.sh --prefix DIR     install somewhere else
#   ./install.sh --uninstall      remove Ganbattea (add --purge to delete saved presets, too)
#   ./install.sh --help           show this help

set -euo pipefail

APP="ganbattea"
APP_NAME="Ganbattea"
PREFIX="${HOME}/.local"
UNINSTALL=0
PURGE=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -t 1 ]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; RESET=""
fi
info() { printf '%s==>%s %s\n' "$GREEN$BOLD" "$RESET" "$*"; }
warn() { printf '%s!!%s  %s\n' "$YELLOW$BOLD" "$RESET" "$*" >&2; }
die()  { printf '%sxx%s  %s\n' "$RED$BOLD" "$RESET" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
  awk 'NR >= 3 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)    [ $# -ge 2 ] || die "--prefix needs a directory"; PREFIX="$2"; shift ;;
    --prefix=*)  PREFIX="${1#*=}" ;;
    --system)    PREFIX="/usr/local" ;;
    --uninstall) UNINSTALL=1 ;;
    --purge)     PURGE=1 ;;
    -h|--help)   usage; exit 0 ;;
    *)           die "Unknown option: $1 (see --help)" ;;
  esac
  shift
done

[ "$(uname -s)" = "Linux" ] || die "Ganbattea's installer only supports Linux."

BIN_DIR="$PREFIX/bin"
DESKTOP_DIR="$PREFIX/share/applications"
ICON_DIR="$PREFIX/share/icons/hicolor/scalable/apps"

# Use sudo only if the target location is not writable by the current user.
SUDO=""
dir="$PREFIX"
while [ ! -d "$dir" ]; do dir="$(dirname "$dir")"; done
if [ "$(id -u)" -ne 0 ] && [ ! -w "$dir" ]; then
  have sudo || die "$PREFIX is not writable and sudo is not available. Choose another --prefix."
  SUDO="sudo"
fi

refresh_caches() {
  if have update-desktop-database; then
    $SUDO update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
  fi
  if have gtk-update-icon-cache && [ -d "$PREFIX/share/icons/hicolor" ]; then
    $SUDO gtk-update-icon-cache -q -t -f "$PREFIX/share/icons/hicolor" >/dev/null 2>&1 || true
  fi
}

# ---------- uninstall ----------

if [ "$UNINSTALL" -eq 1 ]; then
  info "Removing $APP_NAME from $PREFIX"
  $SUDO rm -f "$BIN_DIR/$APP" "$DESKTOP_DIR/$APP.desktop" "$ICON_DIR/$APP.svg"
  refresh_caches
  if [ "$PURGE" -eq 1 ]; then
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APP"
    info "Deleting saved presets in $CONFIG_DIR"
    rm -rf "$CONFIG_DIR"
  else
    info "Your presets were kept (use --purge to delete them)."
  fi
  info "Done."
  exit 0
fi

# ---------- install ----------

# The binary sits next to this script in the release archive
# (or in ../target/release when run from a source checkout after `cargo build --release`).
BINARY=""
for candidate in "$SCRIPT_DIR/$APP" "$SCRIPT_DIR/../target/release/$APP"; do
  if [ -f "$candidate" ]; then BINARY="$candidate"; break; fi
done
[ -n "$BINARY" ] || die "Could not find the '$APP' binary next to install.sh."

ICON="$SCRIPT_DIR/$APP.svg"
[ -f "$ICON" ] || die "Could not find $APP.svg next to install.sh."

info "Installing $APP_NAME to $PREFIX"
$SUDO install -d "$BIN_DIR" "$DESKTOP_DIR" "$ICON_DIR"
$SUDO install -m 755 "$BINARY" "$BIN_DIR/$APP"
$SUDO install -m 644 "$ICON" "$ICON_DIR/$APP.svg"

DESKTOP_FILE="$(mktemp)"
trap 'rm -f "$DESKTOP_FILE"' EXIT
cat > "$DESKTOP_FILE" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$APP_NAME
GenericName=Tea Timer
Comment=A modern tea timer and stopwatch with custom presets
Exec=$BIN_DIR/$APP
Icon=$APP
Terminal=false
Categories=Utility;Clock;
Keywords=tea;timer;stopwatch;alarm;
DESKTOP
$SUDO install -m 644 "$DESKTOP_FILE" "$DESKTOP_DIR/$APP.desktop"

refresh_caches

info "$APP_NAME installed. 🍵"
echo "    Binary:   $BIN_DIR/$APP"
echo "    Launcher: $DESKTOP_DIR/$APP.desktop (look for \"$APP_NAME\" in your start menu)"
case ":$PATH:" in
  *":$BIN_DIR:"*) echo "    Terminal: $APP" ;;
  *) echo "    Terminal: $BIN_DIR/$APP   (not in your PATH)" ;;
esac

# Friendly hint if system libraries are missing.
MISSING="$(ldd "$BIN_DIR/$APP" 2>/dev/null | awk '/not found/ { print $1 }' | tr '\n' ' ' || true)"
if [ -n "${MISSING// /}" ]; then
  warn "Missing system libraries: $MISSING"
  warn "On Debian/Ubuntu: sudo apt install libqt5quick5 libqt5qml5 qml-module-qtquick2 \\"
  warn "                  qml-module-qtquick-window2 qml-module-qtquick-layouts libasound2"
  warn "See README.txt for other distributions."
fi
echo "    Uninstall: ./install.sh --uninstall"
