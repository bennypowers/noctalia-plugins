# Background Apps

Noctalia 5.3.0+ bar widget that shows Freedesktop background apps as tray-style icons.

## Tray integration

The built-in `tray` widget displays StatusNotifierItems (SNI) only. Noctalia's plugin API does not let a plugin
register SNI items, so background apps cannot be injected into that widget. Instead, this widget reproduces the tray's
inline metrics: 16 px icons, 4 px gaps, one bar capsule, per-item tooltips, and no whole-widget hover tint.

Place it next to the tray widget in the bar. For matching spacing between the two widgets, set
`match_adjacent_spacing = true` on the tray widget and give both widgets the same capsule settings.

## Features

- One icon per app running in the background (no visible windows)
- Tooltips with the app name and, when available, its background status message
- Click an icon, or the widget, to open a panel with the full list
- Click a panel row to launch the app
- Auto-hides when no background apps are running

## Detection

### Portal (preferred)

Reads `org.freedesktop.background.Monitor.BackgroundApps` over D-Bus with `gdbus`. Apps that report themselves to the
portal also supply the status message shown in the tooltip and panel.

When the portal returns no apps, the fallback detector runs.

### Flatpak + Niri (fallback)

1. Lists running Flatpaks with `flatpak ps`
2. Lists apps with visible windows with `niri msg windows`
3. Treats running Flatpaks without a window as background apps

The fallback only runs on Niri; without `niri` it reports no apps rather than mislabeling every Flatpak.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `updateInterval` | 3000 | Polling interval in milliseconds |

## Requirements

- `xdg-desktop-portal` with a background monitor implementation for the preferred path
- `flatpak` and `niri` for the fallback path

## License

GPLv3
