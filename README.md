# kwin-effects-swiperemap

A small KWin effect for Plasma 6 that changes two touchpad gestures:

- **Horizontal swipes are inverted.** Swiping left moves to the desktop on the
  right, and the same for four-finger swipes.
- **Three-finger vertical swipes become four-finger ones**, which KWin maps to
  Overview (up) and Grid (down). On a single row of desktops the three-finger
  vertical gesture does nothing at all, so nothing is lost.

The gesture handling itself stays native: the effect only rewrites the finger
count and mirrors the horizontal delta before KWin reads them. The live preview
(the desktop follows your fingers) and the switch on release are still KWin's
own.

## This is a workaround, not a feature

Plasma has no setting for either of these. When gestures become configurable
upstream ([bug 402857](https://bugs.kde.org/show_bug.cgi?id=402857)), this
effect has no reason to exist. Until then it is a hack that has to be rebuilt
after every KWin update.

## Requirements

Plasma 6 / KWin 6.x (developed on 6.7.5, Wayland only so far), a touchpad, and
the build tools plus the KWin development files. `install.sh` checks for them
and prints the exact package names for your distribution if something is
missing.

## Install

```sh
git clone https://github.com/crabiosa/kwin-effects-swiperemap
cd kwin-effects-swiperemap
./install.sh
```

The effect is installed **system-wide**, so the script will ask for your sudo
password once. It says so right before asking. No logout is needed: KWin picks
the effect up in the running session.

## Uninstall

```sh
./uninstall.sh
```

## After a Plasma update

If the swipes suddenly go back to the KWin defaults, a KWin update happened.
KWin rejects third-party effects built against another version, silently and
without an error, so the effect simply stops loading. There is nothing to
diagnose or reinstall:

```sh
./install.sh
```

If the script reports that the .so was built for a newer KWin than the running
session, log out and back in once — the system was updated underneath your
session, and the effect loads with the new KWin.

## No settings

The behaviour is fixed on purpose. If you want it different (only inverting
some gestures, other finger counts, a different action), fork the repository and
hand it to your AI agent: the effect is one small C++ file and the scripts
around it are plain bash.

## No support

Issues and pull requests are not accepted, and there is no support. This is a
personal tool that happens to be useful to others.

## Why not InputActions or a KWin script

[InputActions](https://github.com/taj-ny/InputActions) is the usual answer for
custom gestures, but it turns a gesture into a global shortcut: the gesture is
consumed and the action fires discretely, so the desktop no longer follows your
fingers. This effect was written for exactly that difference — to keep the
native feel and still change the direction. KWin scripts cannot do it at all,
because they have no access to input events.

## Troubleshooting

Is the effect loaded right now?

```sh
busctl --user call org.kde.KWin /Effects org.kde.kwin.Effects isEffectLoaded s swiperemap
```

What did the effect itself log? (One line per KWin start; gesture events are
debug, see the comment in the source for how to switch them on.)

```sh
journalctl --user QT_CATEGORY=kwin_effect_swiperemap
```

Other tools that grab touchpad gestures, such as InputActions, will fight with
this effect; keep only one of them enabled.

The swipe events carry no device, so the effect cannot tell a touchpad from
anything else that produces pointer swipe gestures on your system.

## License

GPL-2.0-or-later, see [LICENSE](LICENSE).
