# CPU Thread Bars Desktop Widget

A Noctalia desktop widget that displays CPU usage bars for each thread/core with a RAM usage indicator.

## Features

- Real-time CPU usage visualization with one bar per CPU thread/core
- Color-coded usage levels:
  - Green: < 25% usage
  - Yellow: 25-50% usage
  - Orange: 50-75% usage
  - Red: > 75% usage
- RAM usage indicator bar
- Smooth animations
- Compact design suitable for desktop widgets
- Updates every 2 seconds

## Installation

1. Copy this plugin directory to `~/.config/noctalia/plugins/`
2. Restart Noctalia or reload plugins
3. Enable the plugin in Noctalia Settings
4. Add the "CPU Thread Bars" widget to your desktop

## Configuration

The widget automatically detects the number of CPU cores/threads and adjusts its height accordingly. No additional configuration is required.

## Technical Details

- Built using Qt Quick and Quickshell
- Uses `/proc/stat` for per-core CPU usage
- Uses `free` command for RAM usage statistics
- Integrates with Noctalia's theming system

## License

MIT

## Credits

Based on the quickshell system monitor bars component.
