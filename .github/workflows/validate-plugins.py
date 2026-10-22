#!/usr/bin/env python3
"""Validate Noctalia 5.3.0 plugin manifests, entries, translations, and catalog."""

from __future__ import annotations

import json
import re
import sys
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
KEY_RE = re.compile(r"^[a-z0-9-][a-z0-9_-]*(\.[a-z0-9-][a-z0-9_-]*)*$")
ENTRY_KINDS = ("widget", "panel", "shortcut", "desktop_widget", "launcher_provider", "service")
SETTING_KINDS = ("widget", "panel", "desktop_widget")
PANEL_PLACEMENTS = {"attached", "floating"}
OLDEST_API = 3
NEWEST_API = 34  # Noctalia 5.3.0 (kCurrentPluginApiVersion)


class Problems:
    def __init__(self) -> None:
        self.messages: list[str] = []

    def add(self, path: Path | str, message: str) -> None:
        self.messages.append(f"{path}: {message}")

    def ok(self) -> bool:
        return not self.messages


def read_toml(path: Path, problems: Problems) -> dict | None:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as error:
        problems.add(path.relative_to(ROOT), f"cannot read TOML: {error}")
        return None


def resolve_translation(data: dict, key: str) -> bool:
    current: object = data
    for part in key.split("."):
        if not isinstance(current, dict) or part not in current:
            return False
        current = current[part]
    return isinstance(current, str)


def check_setting(
    setting: object, translations: dict, problems: Problems, where: Path | str
) -> None:
    if not isinstance(setting, dict):
        problems.add(where, "setting must be a table")
        return
    key = setting.get("key")
    if not isinstance(key, str) or not key:
        problems.add(where, "setting is missing 'key'")
        return
    if "label" in setting or "description" in setting:
        problems.add(where, f"setting '{key}' uses literal 'label'/'description'; use translation keys")
    label_key = setting.get("label_key")
    if not isinstance(label_key, str) or not label_key:
        problems.add(where, f"setting '{key}' is missing 'label_key'")
    else:
        if not KEY_RE.fullmatch(label_key):
            problems.add(where, f"setting '{key}' label_key '{label_key}' is not a valid translation key")
        if not resolve_translation(translations, label_key):
            problems.add(where, f"setting '{key}' label_key '{label_key}' is missing from translations/en.json")

    description_key = setting.get("description_key")
    if description_key is not None:
        if not isinstance(description_key, str) or not KEY_RE.fullmatch(description_key):
            problems.add(where, f"setting '{key}' description_key is not a valid translation key")
        elif not resolve_translation(translations, description_key):
            problems.add(
                where, f"setting '{key}' description_key '{description_key}' is missing from translations/en.json"
            )

    options = setting.get("options")
    if options is not None:
        if not isinstance(options, list):
            problems.add(where, f"setting '{key}' options must be an array")
        else:
            for option in options:
                if not isinstance(option, dict) or not isinstance(option.get("value"), str):
                    problems.add(where, f"setting '{key}' has an option without a string 'value'")
                    continue
                option_key = option.get("label_key")
                if not isinstance(option_key, str) or not option_key:
                    problems.add(where, f"setting '{key}' option '{option['value']}' is missing 'label_key'")
                elif not resolve_translation(translations, option_key):
                    problems.add(
                        where,
                        f"setting '{key}' option '{option['value']}' label_key '{option_key}' is missing "
                        "from translations/en.json",
                    )


def check_plugin(directory: Path, problems: Problems) -> dict | None:
    manifest_path = directory / "plugin.toml"
    manifest = read_toml(manifest_path, problems)
    if manifest is None:
        return None

    rel = manifest_path.relative_to(ROOT)
    for field in ("id", "name", "version"):
        if not isinstance(manifest.get(field), str) or not manifest.get(field):
            problems.add(rel, f"missing mandatory string '{field}'")

    plugin_id = manifest.get("id")
    if isinstance(plugin_id, str):
        if not re.fullmatch(r"[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*", plugin_id):
            problems.add(rel, f"invalid id '{plugin_id}' (expected <author>/<plugin>)")
        elif plugin_id.split("/", 1)[1] != directory.name:
            problems.add(rel, f"id '{plugin_id}' does not match directory '{directory.name}'")

    version = manifest.get("version")
    if isinstance(version, str) and not SEMVER_RE.fullmatch(version):
        problems.add(rel, f"invalid version '{version}' (expected MAJOR.MINOR.PATCH)")

    plugin_api = manifest.get("plugin_api")
    if not isinstance(plugin_api, int) or isinstance(plugin_api, bool):
        problems.add(rel, "missing or invalid 'plugin_api' (expected a positive integer)")
        plugin_api = None
    elif not OLDEST_API <= plugin_api <= NEWEST_API:
        problems.add(rel, f"plugin_api {plugin_api} is outside Noctalia 5.3.0's range {OLDEST_API}-{NEWEST_API}")

    translations_path = directory / "translations" / "en.json"
    try:
        translations = json.loads(translations_path.read_text(encoding="utf-8"))
        if not isinstance(translations, dict):
            raise ValueError("expected a JSON object")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        problems.add(translations_path.relative_to(ROOT), f"cannot read translations: {error}")
        translations = {}

    for setting in manifest.get("setting", []):
        check_setting(setting, translations, problems, rel)

    seen_ids: set[str] = set()
    for kind in ENTRY_KINDS:
        entries = manifest.get(kind)
        if entries is None:
            continue
        if not isinstance(entries, list):
            problems.add(rel, f"'[[{kind}]]' must be an array of tables")
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                problems.add(rel, f"'[[{kind}]]' entry must be a table")
                continue
            entry_id = entry.get("id")
            if not isinstance(entry_id, str) or not entry_id:
                problems.add(rel, f"'{kind}' entry is missing 'id'")
                continue
            if entry_id in seen_ids:
                problems.add(rel, f"duplicate entry id '{entry_id}'")
            seen_ids.add(entry_id)

            entry_file = entry.get("entry")
            if not isinstance(entry_file, str) or not entry_file.endswith(".luau"):
                problems.add(rel, f"entry '{entry_id}' is missing a .luau 'entry'")
            elif not (directory / entry_file).is_file():
                problems.add(rel, f"entry '{entry_id}' points at missing file '{entry_file}'")

            if kind not in SETTING_KINDS and entry.get("setting"):
                problems.add(rel, f"entry '{entry_id}' of kind '{kind}' cannot declare settings")

            for setting in entry.get("setting", []):
                check_setting(setting, translations, problems, f"{rel} [{entry_id}]")

            if kind == "widget" and entry.get("hover_highlight") is not None:
                if plugin_api is not None and plugin_api < 34:
                    problems.add(rel, f"entry '{entry_id}' uses hover_highlight, which requires plugin_api >= 34")

            if kind == "panel":
                placement = entry.get("placement", "floating")
                if placement not in PANEL_PLACEMENTS:
                    problems.add(rel, f"panel '{entry_id}' has invalid placement '{placement}'")
                for extent in ("width", "height"):
                    value = entry.get(extent)
                    if value is None:
                        continue
                    if value == "fill":
                        if placement != "floating":
                            problems.add(rel, f"panel '{entry_id}' {extent}='fill' requires placement='floating'")
                    elif not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
                        problems.add(rel, f"panel '{entry_id}' {extent} must be a positive number or 'fill'")

    return manifest


def check_catalog(manifests: dict[str, dict], problems: Problems) -> None:
    catalog_path = ROOT / "catalog.toml"
    catalog = read_toml(catalog_path, problems)
    if catalog is None:
        return
    rows = catalog.get("plugin", [])
    if not isinstance(rows, list):
        problems.add(catalog_path.relative_to(ROOT), "'plugin' must be an array of tables")
        return

    by_id: dict[str, dict] = {}
    for row in rows:
        if not isinstance(row, dict):
            problems.add(catalog_path.relative_to(ROOT), "plugin row must be a table")
            continue
        row_id = row.get("id")
        if not isinstance(row_id, str) or not row_id:
            problems.add(catalog_path.relative_to(ROOT), "plugin row is missing 'id'")
            continue
        if "min_noctalia" in row:
            problems.add(catalog_path.relative_to(ROOT), f"plugin '{row_id}' uses obsolete 'min_noctalia'; use 'plugin_api'")
        if not isinstance(row.get("name"), str) or not row.get("name"):
            problems.add(catalog_path.relative_to(ROOT), f"plugin '{row_id}' is missing 'name'")
        if not isinstance(row.get("plugin_api"), int) or isinstance(row.get("plugin_api"), bool):
            problems.add(catalog_path.relative_to(ROOT), f"plugin '{row_id}' is missing integer 'plugin_api'")
        by_id[row_id] = row

    for plugin_id, manifest in manifests.items():
        row = by_id.get(plugin_id)
        if row is None:
            problems.add(catalog_path.relative_to(ROOT), f"missing catalog row for '{plugin_id}'")
            continue
        for field in ("version", "plugin_api"):
            if row.get(field) != manifest.get(field):
                problems.add(
                    catalog_path.relative_to(ROOT),
                    f"plugin '{plugin_id}' {field} is {row.get(field)!r}, manifest has {manifest.get(field)!r}",
                )

    for row_id in by_id:
        if row_id not in manifests:
            problems.add(catalog_path.relative_to(ROOT), f"plugin '{row_id}' has no matching plugin directory")


def main() -> int:
    problems = Problems()
    manifests: dict[str, dict] = {}

    for manifest_path in sorted(ROOT.glob("*/plugin.toml")):
        manifest = check_plugin(manifest_path.parent, problems)
        if manifest is not None and isinstance(manifest.get("id"), str):
            manifests[manifest["id"]] = manifest

    if not manifests:
        problems.add(ROOT, "no plugin directories with plugin.toml found")

    check_catalog(manifests, problems)

    if problems.messages:
        for message in problems.messages:
            print(f"error: {message}", file=sys.stderr)
        print(f"{len(problems.messages)} problem(s)", file=sys.stderr)
        return 1

    print(f"validated {len(manifests)} plugin(s) and catalog.toml")
    return 0


if __name__ == "__main__":
    sys.exit(main())
