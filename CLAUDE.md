## Adding a New Plugin

- See ./.github/workflows/README.md for validation and catalog requirements
- Docs: https://docs.noctalia.dev/development/plugins/getting-started/
- API reference: https://docs.noctalia.dev/development/plugins/api/
- Noctalia 5.3.0 source (when installed): https://github.com/noctalia-dev/noctalia-shell/tree/v5.3.0
- The local catalog (`catalog.toml`) is maintained by hand and validated in CI

## Writing Plugins

This repo targets the Noctalia 5.3.0 TOML/Luau plugin format. Do not add v4 `manifest.json` or QML entries.

### Plugin structure

| Path | Purpose |
|------|---------|
| `plugin.toml` | Manifest: id, name, version, `plugin_api`, entries, settings |
| `*.luau` | Entry scripts (widget, panel, service, shortcut, launcher provider, desktop widget) |
| `translations/en.json` | Required when the manifest declares settings or scripts use `noctalia.tr` |
| `README.md` | Plugin documentation |
| `catalog.toml` row | Must match id, version, and `plugin_api` |

Noctalia 5.3.0 supports `plugin_api` 3 through 34. Use the oldest level that covers the features you need. For
example, `hover_highlight = false` on a widget requires 34.

### Manifest

```toml
id          = "author/plugin"
name        = "Plugin"
version     = "1.0.0"
plugin_api  = 3
author      = "author"
license     = "GPL-3.0"
icon        = "puzzle"
description = "What it does"
tags        = ["utility"]

[[setting]]
key             = "interval"
type            = "int"
label_key       = "settings.interval.label"
description_key = "settings.interval.description"
default         = 3000

[[widget]]
id    = "main"
entry = "widget.luau"

[[panel]]
id        = "details"
entry     = "panel.luau"
width     = 360
height    = 420
placement = "attached"
```

Rules specific to 5.3.0:

- `plugin_api` is mandatory; `min_noctalia` is obsolete and rejected.
- Settings use `label_key` / `description_key`; literal `label` / `description` fields are rejected.
- Select options use `{ value, label_key }`.
- Entry-level settings are only allowed on `widget`, `desktop_widget`, and `panel` entries. Put shared settings at the
  manifest root.
- `width = "fill"` / `height = "fill"` on a panel requires `placement = "floating"`.

### Scripting

- Widgets: `barWidget.*` imperative methods or `barWidget.render(ui.*)`.
- Panels/desktop widgets: `panel.render(ui.*)` / `desktopWidget.render(ui.*)`.
- Services: headless polling loops; publish data with `noctalia.state.set` for widgets and panels.
- Use `noctalia.appIconPath(appId, sizePx)` for app icons; the path plugs into `ui.image`.
- Noctalia's tray widget is StatusNotifierItem-only, and plugins cannot register SNI items. A plugin cannot inject items
  into an existing tray widget; reproduce its metrics in a plugin widget instead.

### Testing

```sh
noctalia plugins lint <plugin-dir>
python3 .github/workflows/validate-plugins.py
for test in tests/*.lua; do lua "$test"; done
```

`noctalia plugins lint` cross-checks declared settings against `noctalia.getConfig` calls. The Python validator checks
the manifest, translations, entry files, and catalog consistency. Add pure-Lua tests under `tests/` for parsing logic.
