# Plugin validation

This directory validates the Noctalia 5.3.0 plugin format.

## validate-plugins.py

Checks every `*/plugin.toml` and the root `catalog.toml`:

- required manifest fields, `plugin_api`, and semantic version
- entry ids, entry files, and settings scope
- translation keys resolve in `translations/en.json`
- panel sizes and placement rules
- `hover_highlight` requires `plugin_api >= 34`
- catalog rows match each plugin's id, version, and `plugin_api`

Run locally:

```sh
python3 .github/workflows/validate-plugins.py
```

## validate-plugins.yaml

Runs the validator on pushes to `main`, pull requests, and manual dispatch. It also runs the
background-apps parser tests with Lua 5.4.

## Adding a plugin

1. Create a directory whose name matches the part of the id after `/`.
2. Add `plugin.toml` with `id`, `name`, `version`, `plugin_api`, entries, and settings.
3. Add `translations/en.json` containing every `label_key`, `description_key`, and option `label_key`.
4. Add the entry `.luau` files and a `README.md`.
5. Add a matching row to `catalog.toml`.
6. Run `noctalia plugins lint <plugin-dir>` and the validator.
