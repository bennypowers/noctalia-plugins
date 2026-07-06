# Background Apps Bar Widget

A Noctalia bar widget that displays Freedesktop background apps (like Pika Backup) in the bar, similar to the system tray.

## Features

- Shows icons for apps running in the background (no visible windows)
- Displays status messages (e.g., "Backup running") in tooltips (GNOME only)
- Left-click to activate/focus the app
- Right-click to open a panel with details
- Automatically hides when no background apps are running

## Compatibility

### GNOME Shell
Uses the `org.freedesktop.background.Monitor` DBus interface provided by xdg-desktop-portal-gnome. Apps can set status messages via the portal.

### Niri (and other Wayland compositors)
Falls back to computing background apps by:
1. Getting running Flatpak instances via `flatpak ps`
2. Getting apps with visible windows via `niri msg windows`
3. Background apps = running Flatpaks - apps with windows

Note: On Niri, status messages are not available since the portal's background monitoring doesn't work outside GNOME Shell.

## Requirements

- `xdg-desktop-portal` (for GNOME) or `flatpak` + `niri` (for fallback)
- Flatpak apps that run in the background

## How It Works

Background apps are applications that:
- Are running but have no visible windows
- Examples: Pika Backup (during backups), Steam (downloading), Nextcloud sync, etc.

On GNOME Shell, the portal tracks which apps have called `RequestBackground` and determines which are in the background based on window visibility.

On Niri, we manually compute this by comparing running Flatpak instances against apps with open windows.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `updateInterval` | 3000 | How often to poll for background apps (milliseconds) |

## Installation

1. Copy the `bar-widget-background-apps` folder to your Noctalia plugins directory
2. Add the widget to your bar configuration
3. Restart Noctalia or reload the shell

## License

GPLv3
