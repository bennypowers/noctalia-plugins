# Noctalia Plugins Registry

***Unofficial*** plugin registry for [Noctalia Shell][noctaliashell] based on the [official plugin registry][officialpluginregistry].

## Overview

This repository hosts my personal/forked/non-upstreamed plugins for Noctalia Shell. The `registry.json` file is automatically maintained and provides a centralized index of all available plugins.

## Registry Automation

The plugin registry is automatically maintained using GitHub Actions:

- **Automatic Updates**: Registry updates when manifest.json files are modified
- **PR Validation**: Pull requests show if registry will be updated

See [.github/workflows/README.md][githubworkflowsreadmemd] for technical details.

## Available Plugins

Check [registry.json][registryjson] for the complete list of available plugins.

## License

GPLv3

[noctaliashell]: https://github.com/noctalia-dev/noctalia-shell
[officialpluginregistry]: https://github.com/noctalia-dev/noctalia-plugins
[githubworkflowsreadmemd]: .github/workflows/README.md
[registryjson]: registry.json
