# Screen Recorder — Dank Material Shell Plugin

Plugin for **Dank Material Shell (DMS)** that wraps `gpu-screen-recorder` in a QML UI, letting you start, pause, and stop screen recordings directly from the DankBar. Works on any Wayland compositor.

![Plugin screenshot](assets/screenshot.png)

## Requirements

- [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell) >= 1.2.0
- [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/) installed and in your `PATH`
- A working XDG Desktop Portal for screencasting (required when **Capture source** is set to `portal`)

> **Note:** The [Flatpak version of gpu-screen-recorder](https://flathub.org/en/apps/com.dec05eba.gpu_screen_recorder) is a bundled GUI frontend and is **not supported**. Install the native system package instead.

### Installing gpu-screen-recorder

#### Arch Linux & derivatives
```bash
sudo pacman -S gpu-screen-recorder
```

#### Other distros
See the [official installation guide](https://git.dec05eba.com/gpu-screen-recorder/about).

### XDG Desktop Portal (for portal capture mode)

If screen recording fails with a portal error, install and configure a portal backend:

```bash
# Arch
sudo pacman -S xdg-desktop-portal-gnome
```

Create or edit `~/.config/xdg-desktop-portal/portals.conf`:

```ini
[preferred]
default=gnome;gtk
```

Then restart the portal services:

```bash
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gnome
```

## Installation

```bash
# Clone
git clone https://github.com/arqueon/dms-screen-recorder
ln -sf "$(pwd)/dms-screen-recorder" ~/.config/DankMaterialShell/plugins/screenRecorder

# Reload
dms ipc call plugins reload screenRecorder
```

Then go to **DMS Settings → Plugins** and enable the plugin on the bar.

## Usage

### DankBar controls

| Action | Result |
|--------|--------|
| Left click | Start recording |
| Left click (while recording) | Show **Stop?** confirmation — click again to stop and save |
| Right click or Middle click | Pause / Resume |

When you click to stop, the pill turns orange and shows **Stop?** for 3 seconds. Click again to confirm, or do nothing to cancel and keep recording. This prevents accidentally stopping a recording with a misclick.

### IPC commands (keybinds)

The plugin exposes IPC commands you can bind to keyboard shortcuts:

```bash
dms ipc call screenRecorder toggleRecording   # start or stop
dms ipc call screenRecorder startRecording
dms ipc call screenRecorder stopRecording
dms ipc call screenRecorder togglePause       # pause or resume
```

> **Note:** IPC commands bypass the 3-second stop confirmation. `toggleRecording` stops immediately when a recording is active.

**niri** (`~/.config/niri/config.kdl`):
```kdl
bindings {
    Mod+Alt+R { spawn "dms" "ipc" "call" "screenRecorder" "toggleRecording"; }
    Mod+Alt+P { spawn "dms" "ipc" "call" "screenRecorder" "togglePause"; }
}
```

**Hyprland** (`hyprland.conf`):
```conf
bind = SUPER ALT, R, exec, dms ipc call screenRecorder toggleRecording
bind = SUPER ALT, P, exec, dms ipc call screenRecorder togglePause
```

**Sway** (`~/.config/sway/config`):
```conf
bindsym $mod+Alt+r exec dms ipc call screenRecorder toggleRecording
bindsym $mod+Alt+p exec dms ipc call screenRecorder togglePause
```

**KDE Plasma** (System Settings → Shortcuts → Custom Shortcuts):
Set the trigger command to `dms ipc call screenRecorder toggleRecording`.

**Wayfire / COSMIC / any compositor with custom keybind support:** Run `dms ipc call screenRecorder <method>` as the command.

## Configuration

Open **DMS Settings → Plugins → Screen Recorder**:

| Option | Description | Default |
|--------|-------------|---------|
| **Frames per second** | Recording framerate | 60 |
| **Video quality** | h264 encoding preset | Very high |
| **Record audio** | Capture system audio output | On |
| **Record cursor** | Include mouse pointer | On |
| **Capture source** | `portal` = choose window/screen on start; `screen` = first monitor | portal |
| **Recordings folder** | Output directory (empty = `~/Videos/Screencasting`) | — |
| **Post-record command** | Command to run after recording finishes. Use `$1` to reference the file path. | — |

### Post-record command examples

| Goal | Setting value |
|------|---------------|
| Copy `file://` URI to clipboard | `wl-copy --type text/uri-list "file://$1"` |
| Open file with `dragon-drop` | `dragon-drop "$1"` |
| Open in `mpv` | `mpv "$1"` |
| Copy raw path to clipboard | `wl-copy "$1"` |
| Run a custom script | `~/.local/bin/my-script "$1"` |

The file path is available as `$1` and is fully expanded (e.g. `~/Videos/Screencasting/2026-06-13_09-00-00.mp4`).

## How stopping works

The plugin sends `SIGINT` to `gpu-screen-recorder` so it finalises and saves the MP4 correctly, followed by `SIGKILL` to close any lingering portal window. Do not force-kill the process with `SIGKILL` directly or the file will be incomplete.

## Development

```bash
ln -sf "$(pwd)" ~/.config/DankMaterialShell/plugins/screenRecorder
dms ipc call plugins reload screenRecorder
dms ipc call plugins list
```

## License

MIT
