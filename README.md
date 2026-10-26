# Music for Omarchy

A now-playing widget for the Omarchy top bar. It shows the current track and
artist, and clicking it opens a popup with album art, a seek bar, playback
controls, and a list of every MPRIS player so you can switch sources.

Built for [omarchy-shell](https://github.com/basecamp/omarchy) using Quickshell's
`Quickshell.Services.Mpris` module. Any app that publishes MPRIS works:
Spotify, Firefox, Chromium, VLC, mpv, BitChord, and so on.

## Features

- Track title and artist in the bar, with a small "playing" equalizer.
- Long titles scroll; everything else is clipped to a configurable width.
- Album art, title, artist, album, and source name in the popup.
- Seek bar plus elapsed/total time. Dragging the bar seeks; `-10` / `+10`
  buttons jump ten seconds.
- Previous track, play/pause, next track.
- Source switcher listing every active MPRIS player, sorted with playing
  players first. Selecting a row pins that player until it disappears.
- Automatically follows whichever player is playing, falling back to the last
  one with metadata.
- Styled entirely with Omarchy's theme (`Style`, `Commons.Color`, `qs.Ui`
  components), so it matches the rest of the shell and live theme changes.
- IPC endpoint (`music`) for scripting and keybindings.

## Requirements

- Omarchy with `omarchy-shell` (Quickshell)
- A media app that exposes MPRIS over D-Bus

No build step and no extra packages. The plugin only uses QML modules that ship
with Quickshell and Omarchy.

## Install

```bash
./install.sh
```

The script copies `manifest.json`, `Service.qml`, and `BarWidget.qml` to
`~/.config/omarchy/plugins/dj.music/`, validates the plugin, rescans plugins,
and asks where to place the widget on the bar:

```text
Place Music on which bar section? [center/left/right] (center):
```

Press Enter for the center section, or type `left` / `right`. An invalid answer
asks again, so the layout is never left half-changed.

Choose without a prompt when scripting or reinstalling:

```bash
./install.sh --section left     # or: ./install.sh left
./install.sh --section right
MUSIC_SECTION=center ./install.sh
```

Re-running with a different section moves the existing widget instead of adding
a duplicate. When there is no terminal (for example output piped to a file), the
installer defaults to `center`.

If the widget does not appear, reload the shell:

```bash
omarchy restart shell
```

### Manual install

```bash
dest="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/dj.music"
mkdir -p "$dest"
cp manifest.json Service.qml BarWidget.qml "$dest"/
omarchy plugin validate "$dest"
omarchy-shell shell rescanPlugins
omarchy bar put dj.music --section center   # or left / right
```

Move it later without reinstalling:

```bash
omarchy bar move dj.music --section left
omarchy bar move dj.music --section right
omarchy bar move dj.music --section center --index 5
```

## Uninstall

```bash
./uninstall.sh
```

This disables the plugin, removes its directory, and rescans. It does not touch
the bar layout beyond removing the widget; if you want to fill the gap with a
different media widget, add it with `omarchy bar put <id> --section center`
(or whichever section you used).

## Usage

| Where | Action | Result |
| --- | --- | --- |
| Bar | Left click | Open/close the player popup |
| Bar | Middle click | Play/pause |
| Bar | Right click | Switch to the next source |
| Bar | Scroll up | Previous track |
| Bar | Scroll down | Next track |
| Popup | Seek bar | Drag to seek |
| Popup | `-10` / `+10` | Seek back/forward 10 seconds |
| Popup | Transport buttons | Previous, play/pause, next |
| Popup | Source row | Pin that player |
| Popup | `Esc` | Close |

Hovering the widget shows a tooltip with the full track and player name.

## Settings

Settings are exposed through the Omarchy bar settings UI (`omarchy bar`) and
stored in the bar configuration.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `maxWidth` | integer (60–600) | `220` | Maximum width of the bar label. Longer text scrolls. |
| `showArtist` | boolean | `true` | Show `Title · Artist` instead of just the title. |
| `alwaysShow` | boolean | `false` | Keep the widget visible even when a player has no metadata. |

Set them from the shell, for example:

```bash
omarchy bar set dj.music maxWidth 300
```

## IPC

The service registers an `IpcHandler` with target `music`:

```bash
omarchy-shell music status            # JSON snapshot of the active player
omarchy-shell music playPause         # toggle playback
omarchy-shell music play
omarchy-shell music pause
omarchy-shell music next
omarchy-shell music previous
omarchy-shell music seekBack          # -10s
omarchy-shell music seekForward       # +10s
omarchy-shell music seekTo 90         # absolute seconds
omarchy-shell music sourceNext        # cycle players
omarchy-shell music sourcePrevious
omarchy-shell music selectSource <dbus-name>
omarchy-shell music ping
```

`status` returns:

```json
{
  "playerCount": 2,
  "hasMedia": true,
  "playing": true,
  "identity": "Spotify",
  "title": "Track",
  "artist": "Artist",
  "album": "Album",
  "artUrl": "https://i.scdn.co/image/...",
  "canGoNext": true,
  "canGoPrevious": true,
  "canTogglePlaying": true,
  "canSeek": true,
  "position": 58.45,
  "length": 214.48
}
```

Useful keybinding examples. On current Omarchy (Lua config), add to
`~/.config/hypr/input.lua` and reload Hyprland:

```lua
o.bind("SUPER + M", "Music: play/pause", hl.dsp.exec_cmd("omarchy-shell music playPause"))
o.bind("SUPER + SHIFT + M", "Music: next source", hl.dsp.exec_cmd("omarchy-shell music sourceNext"))
```

On older configs the equivalent is `~/.config/hypr/bindings.conf`:

```conf
bind = SUPER, M, exec, omarchy-shell music playPause
bind = SUPER SHIFT, M, exec, omarchy-shell music sourceNext
```

## Files

| File | Purpose |
| --- | --- |
| `manifest.json` | Plugin metadata, bar widget schema, entry points |
| `Service.qml` | Headless service: MPRIS selection, playback, seek, IPC |
| `BarWidget.qml` | Bar label and popup UI |
| `install.sh` | Install and enable the plugin |
| `uninstall.sh` | Disable and remove the plugin |

The service is mounted once (`keepLoaded: true`) and shared by every monitor's
bar, so player selection persists when a popup is closed or a monitor is
reconfigured.

## How it works

- `Mpris.players` changes only when players appear or disappear, so `Service.qml`
  listens to each player's `isPlaying`, `playbackState`, `metadata`, and track
  signals and bumps a `revision` counter. Active-player and source-list
  bindings depend on that counter and re-evaluate on every change.
- Active player selection order: pinned player (chosen in the popup), then the
  first playing player, then the first player with track metadata, then the
  first controllable player.
- `MprisPlayer.position` does not tick on its own. While playing, a 500 ms timer
  calls `positionChanged()` so the seek bar and elapsed time stay current.
- Seeking uses `MprisPlayer.seek(offset)` for relative jumps and sets
  `position` for absolute seeks. Both require `canSeek`; absolute seeks also
  require `positionSupported`.
- `artUrl` is normalized: bare absolute paths become `file://` URLs, and only
  `file:`, `http(s):`, `data:`, `image:`, and `qrc:` URLs are passed through.

## Troubleshooting

**The widget is missing.** Some player must be running or have track metadata.
Set `alwaysShow` to keep it visible. If no player is discovered at all,
`omarchy-shell music status` should still return JSON with `playerCount: 0`.

**Controls are greyed out for a moment.** MPRIS `can*` properties load over
D-Bus after the player appears; they enable as soon as the player answers.

**Pause does nothing in one app.** Some players (BitChord, some browsers) expose
MPRIS but ignore `Pause`/`PlayPause`. The widget reports `unhandled` from IPC and
leaves the button enabled if the player claims control. Try the app's own
controls or another player.

**No album art.** The player must provide `mpris:artUrl`. Firefox only does so
with its MPRIS integration enabled; local art appears as
`file:///home/<user>/.config/mozilla/firefox/firefox-mpris/...png`.

**Wrong player is shown.** Left-click the widget and pick another source, or run
`omarchy-shell music sourceNext`. The pinned source is kept until that player
disappears.

**Changed QML but nothing happened.** The shell caches widget components. Run
`omarchy restart shell` after editing.

**The plugin fails to load.** Validate it and check the shell log:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/dj.music
journalctl --user -f | grep -i dj.music
```

## Notes

- This plugin is named `dj.music`. It is independent of the built-in
  `omarchy.media` widget and of `custom.media` in `~/.config/omarchy/plugins/`.
- The bar shows the widget wherever it is placed. `install.sh` asks for
  `center` (default), `left`, or `right`, and the widget works in any section and
  on bars positioned top, bottom, left, or right.
- MPRIS is the only integration point. Apps that do not expose MPRIS (some
  Electron apps without the flag, for example) will not appear.
