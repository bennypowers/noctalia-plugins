# CPU Thread Bars

Noctalia 5.3.0+ bar widget drawing one compact load stem per CPU core, styled like the built-in `sysmon` gauge.

## Appearance

Each core is a 4 px wide, 17 px tall rounded stem with a 4 px gap. The track is the fill color at 30% alpha, matching
the built-in sysmon gauge. Fill color interpolates from the bar foreground toward the highlight color using the system
monitor's CPU activity and critical thresholds, so the widget follows the same value highlighting as the built-in
`sysmon` widget.

On a vertical bar, the stems rotate to horizontal and stack in a column.

Between samples the stems ease toward their new values with a frame-rate independent interpolation. The widget runs a
50 ms tick while animating, then drops back to the sample interval once settled, so idle CPU cost stays low.

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
| `updateInterval` | 2000 | Sample interval in milliseconds; bars animate between samples |
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
