# Hebrew Calendar Bar Widget

A Noctalia bar widget that displays the current Hebrew date.

## Features

- Real-time Hebrew calendar date display
- **Customizable template format** with settings UI
- **Comprehensive panel** with detailed information:
  - Daily zmanim (prayer times)
  - Daf Yomi (daily Talmud page)
  - This week's candle lighting and Havdalah times
  - Weekly parsha (Torah portion)
  - Upcoming holidays and events
- Compact format suitable for status bars
- Right-to-left text support
- Auto-updates every hour
- Clean, distraction-free design
- Preset templates for common formats

## Dependencies

### Required
- **hebcal** - Jewish calendar generator
  - Gentoo: `emerge -av hebcal`
  - Ubuntu/Debian: `apt install hebcal`
  - Fedora: `dnf install hebcal`
  - Arch: `pacman -S hebcal`
  - macOS: `brew install hebcal`

### Optional
- Hebrew-supporting fonts (for proper Hebrew text rendering)
  - **Liberation Serif** (usually pre-installed on most Linux systems)
  - **DejaVu Serif** - install `dejavu` font package if needed
  - **Noto Sans Hebrew** or **Noto Serif Hebrew** - install `noto-fonts` package
  - The plugin automatically detects available Hebrew fonts at runtime

## Installation

1. Install the `hebcal` command-line utility (see Dependencies above)
2. Copy this plugin directory to `~/.config/noctalia/plugins/`
3. Restart Noctalia or reload plugins
4. Enable the plugin in Noctalia Settings
5. Add the "Hebrew Calendar" widget to your bar

## Usage

The widget displays the current Hebrew date using a customizable template. The default format shows:
```
ט״ו טבת
```

Click on the widget to open a comprehensive panel showing:
- **Daily zmanim**: Prayer times including Alot HaShachar, Misheyakir, sunrise, Shema, Tefilah, Chatzot, Mincha, sunset, and Tzeit Hakochavim
- **Daf Yomi**: Today's Talmud page
- **This week**: Next Shabbat's candle lighting time, Havdalah time, and parsha
- **Upcoming events**: Holidays and special days

### Customizing the Display

Access the plugin settings to configure:

#### Location
- **City**: Set your location for accurate holiday calculations (e.g., Jerusalem, Tel Aviv, New York)
- Quick-select buttons for common cities

#### Holiday Schedule
- **Israeli**: Use Israeli holiday schedule (one-day festivals)
- **Diaspora**: Use Diaspora holiday schedule (two-day festivals)

#### Language
Choose how the Hebrew date is displayed:
- **Hebrew (no vowels)**: `ראשון, ט״ו טבת תשפ״ו` (default)
- **Hebrew (with vowels)**: `ראשון, ט״ו טֵבֵת תשפ״ו`
- **English**: `ראשון, 15 Tevet 5786` (weekday translated to Hebrew)
- **Ashkenazi**: `ראשון, 15 Teves 5786` (weekday translated to Hebrew)

Note: Weekday names are always displayed in Hebrew regardless of language setting.

#### Template Format
Customize the exact output using template placeholders:

- `{day}` - Hebrew day number (e.g., ד׳, כ״א)
- `{month}` - Hebrew month name (e.g., טבת, ניסן)
- `{year}` - Hebrew year (e.g., ה׳תשפ״ה)
- `{weekday}` - Hebrew weekday name (e.g., ראשון, שני)

### Preset Templates

The settings UI includes several preset formats:

1. **Day and Month** (default): `{day} {month}` → `ד׳ טבת`
2. **Day, Month, Year**: `{day} {month} {year}` → `ד׳ טבת ה׳תשפ״ה`
3. **Weekday and Date**: `{weekday}, {day} {month}` → `ראשון, ד׳ טבת`
4. **Full Date**: `{weekday}, {day} {month} {year}` → `ראשון, ד׳ טבת ה׳תשפ״ה`
5. **Month and Day**: `{month} {day}` → `טבת ד׳`
6. **Day Only**: `{day}` → `ד׳`

You can also create custom templates with any combination of placeholders and text.

## Technical Details

- Uses the `hebcal` command to get the current Hebrew date
- Built using Qt Quick and Quickshell
- Integrates with Noctalia's theming system (Color service)
- Updates automatically every hour via Timer
- Supports both vertical and horizontal bar orientations
- Dynamic command building based on user settings

## Hebrew Date Format

The widget uses Hebrew numerals and month names:
- Days: א׳-ל׳ (1-30 with geresh/gershayim)
- Months: ניסן, אייר, סיוון, תמוז, אב, אלול, תשרי, חשוון, כסלו, טבת, שבט, אדר
- Years: Hebrew numerals with ה׳ prefix (e.g., ה׳תשפ״ה)

## Troubleshooting

### Widget shows blank or incorrect date
- Verify `hebcal` is installed: `which hebcal`
- Test command manually: `hebcal --lang he-x-NoNikud --city Jerusalem -iT`
- Check console logs for errors: `journalctl -f | grep qs`
- Verify your city name is recognized: `hebcal cities | grep -i "your city"`

### Hebrew text displays incorrectly
- Check available Hebrew fonts: `fc-list :lang=he family`
- Install Hebrew-supporting fonts:
  - Liberation fonts: Usually pre-installed
  - DejaVu fonts: Install `dejavu` package
  - Noto fonts: Install `noto-fonts` or `fonts-noto` package
- Select an available font in the plugin settings

## Architecture

- **BarWidget.qml**: Main bar widget component with template formatting and click-to-open panel
- **Panel.qml**: Comprehensive information panel with:
  - Daily zmanim display with formatted list
  - Daf Yomi learning tracker
  - This week's Shabbat times and parsha
  - Upcoming events calendar
  - Multiple hebcal processes for different data sources
- **Settings.qml**: Comprehensive settings UI with:
  - Font family selection with live preview
  - Runtime font detection via `fc-list :lang=he`
  - City selection (text input + quick buttons)
  - Israeli/Diaspora toggle
  - Language selector with examples
  - Template editor with presets
- **manifest.json**: Plugin metadata, entry points (bar widget, panel, settings), and default settings
- Uses Quickshell Process to execute `hebcal -w -T` command with dynamic flags
- Runtime Hebrew font detection for better cross-system compatibility
- Hebrew numeral conversion function included
- Weekday name conversion (English abbreviations → Hebrew names)
- RTL (right-to-left) text layout support
- Dual-format parser for Hebrew and English hebcal output
- Template system with placeholder replacement

## License

GPLv3

## Credits

Based on HebrewCalendar.qml and ClockWidget.qml from the quickshell configuration.
Uses the `hebcal` utility from [hebcal.com](https://www.hebcal.com/).
