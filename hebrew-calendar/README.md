# Hebrew Calendar

Noctalia v5 bar widget displaying the current Hebrew date with a full calendar panel.

## Features

- Hebrew date in the bar with customizable template format
- Panel with:
  - Header card (day numeral, month, year, daf yomi, sefirat haomer)
  - Month calendar grid
  - Zmanim (prayer times) with passed/next/upcoming status
  - Shabbat card (parsha, candle lighting, havdalah)
- Auto-updates every hour

## Dependencies

- **hebcal** -- Jewish calendar generator
  - Gentoo: `emerge -av hebcal`
  - Arch: `pacman -S hebcal`
  - Ubuntu/Debian: `apt install hebcal`
  - Fedora: `dnf install hebcal`

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `template` | `{day} {month}` | Display format. Placeholders: `{day}`, `{month}`, `{year}`, `{weekday}` |
| `city` | `Jerusalem` | City for zmanim and candle lighting |
| `israeli` | `true` | Israeli (vs Diaspora) holiday schedule |
| `language` | `he-x-NoNikud` | Display language: `he-x-NoNikud`, `he`, `en`, `ashkenazi` |

## Template Examples

| Template | Output |
|----------|--------|
| `{day} {month}` | ט״ו טבת |
| `{day} {month} {year}` | ט״ו טבת תשפ״ו |
| `{weekday}, {day} {month}` | ראשון, ט״ו טבת |

## Troubleshooting

- Verify hebcal: `which hebcal`
- Test manually: `hebcal --lang he-x-NoNikud --city Jerusalem -iT`
- Check logs: `journalctl --user -u noctalia -f | grep hebrew`

## License

GPLv3
