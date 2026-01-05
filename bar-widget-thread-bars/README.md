# CPU Thread Bars (Bar Widget)

A Noctalia bar widget that displays real-time CPU usage for each thread/core as compact vertical bars. Click the widget to open a detailed performance panel showing comprehensive system metrics.

## Features

### Bar Widget
- **Per-Core CPU Monitoring**: Individual compact vertical bars for each CPU thread/core
- **Color-Coded Status**: Visual indicators based on usage levels:
  - Low usage (< 25%): Primary color
  - Medium usage (25-50%): Secondary color
  - High usage (50-75%): Tertiary color
  - Critical usage (≥ 75%): Error color
- **Hover Effect**: Visual feedback when hovering over the widget
- **Clickable**: Opens detailed performance panel positioned near the widget

### Performance Panel
Focused CPU and process monitoring:

- **Overall CPU**: Total CPU usage percentage
- **Per-Core Usage**: Grid showing individual core utilization with color-coded status
- **Top Processes**: List of the top 5 CPU-consuming processes showing:
  - CPU usage percentage (color-coded)
  - Username
  - Command/process name

## Requirements

### Required Commands
- `top` - CPU usage monitoring
- `free` - RAM usage monitoring
- `grep`, `awk`, `sed` - Data parsing

### Optional Commands
- `ps` - Process monitoring (usually pre-installed)

## Installation

1. Clone or download this plugin to your Noctalia plugins directory
2. The plugin will be automatically discovered by Noctalia
3. Add the widget to your bar through Noctalia's configuration

## Configuration

### Settings

You can configure the following settings in your Noctalia config:

```json
{
  "updateInterval": 2000
}
```

- **updateInterval** (default: 2000ms): How often to refresh CPU and process data

## Usage

1. Add the widget to your bar
2. The widget will display compact vertical bars for each CPU core
3. Click the widget to open the detailed performance panel positioned near the widget
4. The panel shows comprehensive system metrics and updates in real-time

## Color System

The widget uses Noctalia's semantic color system:
- **mPrimary**: Low usage (good performance)
- **mSecondary**: Medium usage
- **mTertiary**: High usage (warning)
- **mError**: Critical usage (alert)

## Notes

- The widget automatically adapts to the number of CPU cores on your system
- The panel focuses on CPU and process information; use the built-in System Monitor widget for comprehensive system metrics (GPU, RAM, disk, network)
- Process list updates every 2 seconds by default (configurable via `updateInterval`)

## License

GPLv3

## Author

Benny Powers <web@bennypowers.com>
