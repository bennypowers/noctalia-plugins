# CPU Thread Bars Desktop Widget

A Noctalia desktop widget that displays CPU usage bars for each thread/core with a RAM usage indicator.

## Features

- Real-time CPU usage visualization with one bar per CPU thread/core
- Color-coded usage levels using Noctalia's semantic color system:
  - Primary (blue): < 25% usage
  - Secondary (teal): 25-50% usage
  - Tertiary (purple): 50-75% usage
  - Error (red): > 75% usage
- RAM usage indicator bar
- **Configurable layouts:**
  - **Vertical**: Bars grow horizontally (LTR or RTL)
  - **Horizontal**: Bars grow vertically (TTB or BTT)
- Smooth animations
- Draggable and scalable (0.5x - 3x)
- Auto-sizing based on CPU core count and layout
- Updates every 2 seconds

## Installation

1. Copy this plugin directory to `~/.config/noctalia/plugins/`
2. Restart Noctalia or reload plugins
3. Enable the plugin in Noctalia Settings
4. Add the "CPU Thread Bars" widget to your desktop

## Usage

- **Drag**: Click and drag the widget to reposition it on your desktop
- **Scale**: Use the scaling controls in edit mode to resize the widget (0.5x - 3x)
- **Configure**: Access plugin settings to customize:
  - **Layout Orientation**: Vertical or Horizontal
  - **Vertical Bar Direction**: Left-to-Right (LTR) or Right-to-Left (RTL)
  - **Horizontal Bar Direction**: Top-to-Bottom (TTB) or Bottom-to-Top (BTT)
- The widget automatically adapts all dimensions when scaled

## Technical Details

- Extends `DraggableDesktopWidget` for drag/scale functionality
- Built using Qt Quick and Quickshell
- Uses `/proc/stat` for per-core CPU usage
- Uses `free` command for RAM usage statistics
- Fully integrated with Noctalia's theming system (Color service)
- All dimensions scale proportionally with `widgetScale`

## Architecture

- **DesktopWidget.qml**: Main widget extending DraggableDesktopWidget with dual layout components (478 lines)
- **Settings.qml**: Settings UI for layout orientation configuration with custom toggle buttons (251 lines)
- **manifest.json**: Plugin metadata, entry points (desktopWidget + settings), and default settings
- Monitors CPU and RAM using Quickshell Process components
- Updates every 2 seconds via Timer
- Dynamic layout switching using QML Loader and Components

## License

GPLv3

## Credits

Based on the quickshell system monitor bars component.
