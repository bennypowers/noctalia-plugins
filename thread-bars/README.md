# CPU Thread Bars

Noctalia 5.3.0+ bar widget drawing one compact load stem per CPU core, styled like the built-in `sysmon` gauge.

## Appearance

Each core is a 4 px wide, 17 px tall rounded stem with a 2 px gap. The track is the fill color at 30% alpha, matching
the built-in sysmon gauge. Fill color interpolates from the bar foreground toward the highlight color using the system
monitor's CPU activity and critical thresholds, so the widget follows the same value highlighting as the built-in
`sysmon` widget.

On a vertical bar, the stems rotate to horizontal and stack in a column.

Between samples the stems ease toward their new values with a frame-rate independent interpolation. The widget runs a
50 ms tick while animating, then idles once settled, so idle CPU cost stays low.

## Details panel

Click the widget to open a panel with:

- one overlaid line graph for every core, with a bolder overall line on top
- a color-coded legend showing each core's current load
- overall CPU stats: peak, average, hottest core, and thread count

Core colors are derived from the active theme's accent colors with golden-angle hue rotation, so high-core-count CPUs
get distinct colors without leaving the current color scheme. The panel keeps the last 30 samples (30 seconds at the
default 1 s interval) and scrolls the graph smoothly between samples, like the built-in sysmon graph.

The graph scroll is rigid: short histories are left-padded to a fixed 30-sample span so the x-axis never squishes, the
history is densified 16x with Catmull-Rom interpolation for smooth curves, and each frame advances an integer grid
offset. That makes consecutive frames exact translations of the previous line. The panel runs one sample behind: the
newest queued sample supplies the right-edge lead, and data is adopted only after the current line finishes scrolling.
Every segment drawn on screen is therefore final and never changes shape.

## Data source

Uses `noctalia.cpuCores()`. This opts into Noctalia's per-core sampler (one extra `/proc/stat` read per second) and
requires the system monitor to be enabled:

```toml
[system.monitor]
enabled = true
```

The first sample arrives up to one second after the widget loads; until then the widget stays hidden.

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `updateInterval` | 1000 | Sample interval in milliseconds; bars animate between samples and the panel keeps 60 points |
| `highlightColor` | `error` | Palette role the bars tint toward at high usage |

Thresholds come from the shell config:

```toml
[system.monitor]
cpu_usage_activity_threshold = 50
cpu_usage_critical_threshold = 90
```

Hover a stem to see its core index and current usage.

## License

GPLv3

## Author

Benny Powers <web@bennypowers.com>
