# Background Apps

Noctalia v5 bar widget that displays Freedesktop background apps.

## Features

- Shows count of apps running in the background (no visible windows)
- Click to open panel with app list
- Panel shows app names (parsed from .desktop files) and status messages
- Click app rows to activate/focus
- Auto-hides when no background apps running

## Detection Methods

### Portal (primary)
Uses `org.freedesktop.background.Monitor` DBus interface. Apps can set status messages via the portal.

### Flatpak + Niri (fallback)
Computes background apps by:
1. Getting running Flatpak instances via `flatpak ps`
2. Getting apps with visible windows via `niri msg windows`
3. Background apps = running Flatpaks - apps with windows

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `updateInterval` | 3000 | Polling interval in milliseconds |

## Requirements

- `xdg-desktop-portal` (for portal method) or `flatpak` + `niri` (for fallback)

## License

GPLv3
