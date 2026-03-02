# Screen Recorder — Dank Material Shell Plugin

Plugin for **Dank Material Shell** that allows you to start, stop, and configure screen captures with **gpu-screen-recorder** on Wayland (niri, Hyprland, GNOME, etc.).

## Requirements

- [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell) (DMS) running on your compositor
- [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/) installed and in your `PATH`
- A working XDG Desktop Portal for screencasting (specifically `xdg-desktop-portal-gnome` is required for many Wayland compositors like niri)

### Installing Dependencies

#### Arch Linux & Derivatives
```bash
# Install gpu-screen-recorder
sudo pacman -S gpu-screen-recorder

# Install GNOME portal for screencasting (Required for niri)
sudo pacman -S xdg-desktop-portal-gnome
```

#### Ubuntu / Debian
```bash
# gpu-screen-recorder is not in the default repos, you may need a PPA or compile from source
# https://git.dec05eba.com/gpu-screen-recorder/

# Install the GNOME portal
sudo apt install xdg-desktop-portal-gnome
```

#### Fedora
```bash
# Install gpu-screen-recorder (Available via Copr or build from source)
# Install the GNOME portal
sudo dnf install xdg-desktop-portal-gnome
```

#### Important: Activating the portal
If your screen recording fails due to a portal issue (e.g., using `niri`), you must configure the desktop portal to prefer GNOME.
Create or edit `~/.config/xdg-desktop-portal/portals.conf` (or `niri-portals.conf` depending on your setup) and add:

```ini
[preferred]
default=gnome;gtk
```

Then restart the services so the changes apply:
```bash
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gnome
```

## Plugin Installation

1. Clone or copy this repository.
2. Link the folder to your DMS plugins directory:

```bash
ln -sf /path/to/dms-screen-recorder ~/.config/DankMaterialShell/plugins/screenRecorder
```

3. Reload plugins (or restart the shell):

```bash
dms ipc call plugins reload screenRecorder
```

4. In **DMS Settings → Plugins**, activate the widget on the bar and/or the Control Center.

## Usage

- **Bar (DankBar):** Camera / "Record" icon. Click to open the popout with **Start** / **Stop and save**.
- **Control Center:** "Screen Recorder" toggle. On = recording; Off = stopped and saved.

### Replay buffer (ShadowPlay style)

In **Plugin Configuration**, set **Replay buffer** > 0 (e.g., 30s). The recording will keep the last N seconds in memory. When you click **Stop**, only that clip will be saved into the replays folder.

## Configuration

In **DMS Settings → Plugins → Screen Recorder**:

| Option | Description |
|--------|-------------|
| **Capture source** | `portal` = choose window/screen on start; `screen` = first screen |
| **Recordings folder** | Where to save videos (full path; defaults to ~/Videos/Screencasting if empty) |
| **Replay buffer** | 0 = continuous recording; >0 = last N seconds |
| **Replays folder** | Where to save clips on stop (if replay > 0) |
| **FPS** | 24–120 |
| **Quality** | ultra / high / medium / low |
| **Format** | mp4, mkv, flv |

## Stop Recording

The plugin stops **gpu-screen-recorder** by sending `SIGUSR1`, so it saves the file correctly. Do not use `pkill -KILL` unless you want to discard the recording.

## Development

Symlink to test changes without reinstalling:

```bash
ln -sf "$(pwd)" ~/.config/DankMaterialShell/plugins/screenRecorder
dms ipc call plugins reload screenRecorder
```

List plugins and state:

```bash
dms ipc call plugins list
```

## License

You can use and modify this plugin under the same terms you accept for DMS and gpu-screen-recorder.
