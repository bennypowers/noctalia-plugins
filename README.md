# Noctalia Plugins

Personal plugins for [Noctalia](https://noctalia.dev/) 5.3.0 and later, using the TOML/Luau plugin format.

## Plugins

| Plugin | Description |
|--------|-------------|
| [background-apps](background-apps/) | Background apps as tray-style icons in the bar |
| [thread-bars](thread-bars/) | Per-core CPU load bars styled like the built-in sysmon gauge |
| [hebrew-calendar](hebrew-calendar/) | Hebrew date display with full calendar panel |
| [nut-status](nut-status/) | UPS battery status from NUT |

## Installation

Add this repo as a plugin source:

```
noctalia msg plugins source add bennypowers git https://github.com/bennypowers/noctalia-plugins
```

Then enable plugins in Settings.

## Development

Each plugin is a directory with a `plugin.toml`, Luau entries, `translations/en.json`, and a README. The repo catalog
lives in `catalog.toml`.

Lint a plugin with:

```
noctalia plugins lint background-apps
```

Run the pure-Lua parser tests with:

```
for test in tests/*.lua; do lua "$test"; done
```

## License

GPLv3
