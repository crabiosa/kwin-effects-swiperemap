#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 crabiosa
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Removes the swiperemap KWin effect from the system. Run it as your normal
# user, not as root: it asks for sudo itself.

set -euo pipefail

effect_id="swiperemap"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step() { printf '\n==> %s\n' "$*"; }
ok()   { printf '    %s\n' "$*"; }
die()  { printf '\nerror: %s\n' "$*" >&2; exit 1; }

kwin_answers() {
    busctl --user call org.kde.KWin /KWin org.kde.KWin supportInformation >/dev/null 2>&1
}

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    die "run this as your normal user, without sudo: the script asks for root only where it needs it"
fi

plugin_root="$(qtpaths6 --plugin-dir 2>/dev/null || qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null || true)"
[[ -n "$plugin_root" ]] || die "cannot locate the Qt plugin directory (qtpaths6 or qmake6 is required)"
dest="$plugin_root/kwin/effects/plugins/$effect_id.so"

step "Stop"
if kwin_answers; then
    if busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects unloadEffect s "$effect_id" >/dev/null 2>&1; then
        ok "unloaded from the running KWin"
    else
        ok "KWin did not report an unload (the effect may not have been loaded)"
    fi
else
    ok "no running KWin session found"
fi

step "Remove"
if [[ -f "$dest" ]]; then
    printf '    this removes a system-wide file and needs root, asking for your password once\n'
    sudo -v || die "sudo failed"
    sudo rm -f "$dest"
    ok "$dest"
else
    ok "nothing installed at $dest"
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kwinrc --group Plugins --key "${effect_id}Enabled" --delete
    ok "removed ${effect_id}Enabled from kwinrc"
else
    ok "warning: kwriteconfig6 not found, check kwinrc by hand"
fi

printf '\nDone. Touchpad swipes are back to KWin defaults.\n'
