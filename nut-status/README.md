# NUT UPS Status

Noctalia 5.3.0+ bar widget showing UPS battery status from Network UPS Tools (NUT).

## Features

- Battery charge, power draw, and on-battery status in the bar
- Auto-detects the first UPS when no name is configured
- Panel with status, load, voltages, temperature, and a charge bar
- Hides itself when `upsc` cannot reach the configured UPS

## Dependencies

- **NUT** -- `upsc` must be on `PATH`
  - Gentoo: `emerge -av sys-power/nut`

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `upsName` | empty | UPS to monitor; empty auto-detects the first one |
| `updateInterval` | 5000 | Polling interval in milliseconds |
| `showPowerDraw` | `true` | Show current power draw |
| `showBatteryOnlyOnBattery` | `true` | Hide the percentage while on mains power |
| `batteryColor` | `error` | Icon color while on battery |
| `powerFactor` | 0.6 | Used to estimate watts when NUT reports no real power |

## Troubleshooting

- Verify NUT: `upsc -l`
- Test a UPS directly: `upsc <name>`
- Check logs: `journalctl --user -u noctalia -f | grep nut`

## License

GPLv3
