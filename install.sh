#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 crabiosa
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Builds and installs the swiperemap KWin effect, then enables it in the running
# session. Run it as your normal user, not as root: it asks for sudo itself.
#
# Safe to run again at any time. This is also the repair command after a KWin
# update, which invalidates every third-party effect (see README).

set -euo pipefail

effect_id="swiperemap"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$here/build"
log="$build_dir/install.log"

step() { printf '\n==> %s\n' "$*"; }
ok()   { printf '    %s\n' "$*"; }
die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }

packages_hint() {
    cat >&2 <<'EOF'

Install the build tools and the KWin development files for your distribution:

  Fedora:        sudo dnf install cmake ninja-build gcc-c++ kwin-devel extra-cmake-modules
  Debian/Ubuntu: sudo apt install cmake ninja-build g++ kwin-dev extra-cmake-modules
  otherwise:     cmake, ninja, a C++ compiler and your distribution's KWin development package
EOF
}

kwin_answers() {
    busctl --user call org.kde.KWin /KWin org.kde.KWin supportInformation >/dev/null 2>&1
}

# Ask for root only when sudo would actually prompt: a passwordless setup (or an
# already authorised sudo) goes through without a single question.
root() {
    sudo -n true 2>/dev/null || sudo -v || die "sudo failed"
}

effect_loaded() {
    [[ "$(busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects isEffectLoaded s "$effect_id" 2>/dev/null || true)" == "b true" ]]
}

running_kwin_version() {
    busctl --user call org.kde.KWin /KWin org.kde.KWin supportInformation 2>/dev/null \
        | grep -oE 'KWin version: [0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk '{print $3}'
}

so_version() {
    grep -ao 'org\.kde\.kwin\.EffectPluginFactory[0-9.]*' "$1" 2>/dev/null | head -1 | sed 's/.*Factory//'
}

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    die "run this as your normal user, without sudo: the script asks for root only where it needs it"
fi

# ------------------------------------------------------------------ build deps
step "Build requirements"
missing=""
for tool in cmake ninja c++; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [[ -n "$missing" ]]; then
    printf 'missing:%s\n' "$missing" >&2
    packages_hint
    exit 1
fi
ok "cmake, ninja, c++"

mkdir -p "$build_dir"
if ! cmake -S "$here/effect" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo >"$log" 2>&1; then
    if grep -qiE "KWin|ECM" "$log"; then
        printf 'The KWin development files (KWinConfig.cmake) or extra-cmake-modules are missing.\n' >&2
        packages_hint
    else
        printf 'cmake failed:\n' >&2
    fi
    tail -n 5 "$log" >&2
    printf '\nFull log: %s\n' "$log" >&2
    exit 1
fi
ok "KWin development files"

# ----------------------------------------------------------------------- build
step "Build"
if ! cmake --build "$build_dir" >>"$log" 2>&1; then
    printf 'build failed:\n' >&2
    tail -n 20 "$log" >&2
    printf '\nFull log: %s\n' "$log" >&2
    exit 1
fi

so_src="$build_dir/pluginroot/kwin/effects/plugins/$effect_id.so"
[[ -f "$so_src" ]] || die "the build produced no $so_src"
built_for="$(so_version "$so_src")"
ok "$effect_id.so built against KWin ${built_for:-an unknown version}"

# --------------------------------------------------------------------- install
plugin_root="$(qtpaths6 --plugin-dir 2>/dev/null || qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null || true)"
[[ -n "$plugin_root" ]] || die "cannot locate the Qt plugin directory (qtpaths6 or qmake6 is required)"
dest="$plugin_root/kwin/effects/plugins/$effect_id.so"

step "Install"
printf '    installing system-wide, so sudo is used, a password prompt may appear here\n'
root

# Replacing a .so that KWin has loaded can take the compositor down, so the
# running copy is stopped first. This is why there is no separate "disable"
# command to remember.
if effect_loaded; then
    busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects unloadEffect s "$effect_id" >/dev/null 2>&1 || true
    ok "stopped the running effect before replacing its file"
fi

sudo install -Dm755 "$so_src" "$dest"
# SELinux (enforcing) needs the system library type, otherwise kwin_wayland
# cannot open the file.
if command -v restorecon >/dev/null 2>&1; then
    sudo restorecon -F "$dest"
fi
ok "$dest"

if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kwinrc --group Plugins --key "${effect_id}Enabled" true
    ok "enabled in kwinrc (${effect_id}Enabled=true)"
else
    ok "warning: kwriteconfig6 not found, the effect will not survive a logout"
fi

# ---------------------------------------------------------------------- verify
step "Verify"
if ! kwin_answers; then
    ok "no running KWin session found"
    printf '\nInstalled and enabled. The effect will load at your next login.\n'
    exit 0
fi

busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects loadEffect s "$effect_id" >/dev/null 2>&1 || true

live_version="$(running_kwin_version)"
so_ver="$(so_version "$dest")"
if [[ -n "$live_version" && -n "$so_ver" && "$so_ver" != "$live_version" ]]; then
    ok "built against KWin $so_ver, running session is KWin $live_version"
    cat <<'EOF'

KWin refuses third-party effects built for another version. Your system was
updated while this session kept the old KWin. Log out and back in: the effect
loads together with the new KWin, nothing else is needed.
EOF
    exit 0
fi

if effect_loaded; then
    ok "running in the current session"
    printf '\nDone. Swipe three fingers right: the desktop now moves to the right.\n'
else
    ok "the effect is not loaded"
    cat <<'EOF'

The file is installed and enabled, but KWin did not load it.
Its own log line would say so: journalctl --user QT_CATEGORY=kwin_effect_swiperemap
EOF
    exit 1
fi
