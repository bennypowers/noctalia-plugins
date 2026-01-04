## Adding a New Plugin

- See ./.github/workflows/README.md for instructions
- Registry is automatically updated via GitHub Actions when manifest.json files are pushed to main

## Writing Plugins

### Documentation
- See https://docs.noctalia.dev/development/plugins/getting-started/ for HOWTO
- See https://docs.noctalia.dev/development/plugins/api/ for Plugin API reference
- See https://github.com/noctalia-dev/noctalia-plugins for official plugin examples

### Plugin Structure
- `manifest.json` - Required metadata (id, name, version, author, description, repository, minNoctaliaVersion, license, entryPoints)
- `BarWidget.qml` or `DesktopWidget.qml` - Entry point for widgets
- `README.md` - Plugin documentation (recommended)

### Required Imports
```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons      // Provides Color and Style services
import qs.Widgets      // Provides widget components
```

**IMPORTANT**: Do NOT import `Noctalia.Color` or `Noctalia.Style` - these modules don't exist. Use `qs.Commons` instead.

### Required Widget Properties
Desktop widgets must declare:
```qml
required property var pluginApi
required property var screen
required property string widgetId
```

### Color System
Access colors through the Color service from `qs.Commons`:
- `Color.mPrimary`, `Color.mSecondary`, `Color.mTertiary` - Accent colors
- `Color.mError` - Error/critical state color
- `Color.mOnSurface`, `Color.mOnSurfaceVariant` - Text colors
- `Color.mSurface`, `Color.mSurfaceVariant` - Background colors
- `Color.mOutline` - Border colors
- `Color.transparent`, `Color.black`, `Color.white` - Absolute colors

See https://github.com/noctalia-dev/noctalia-shell/blob/main/Commons/Color.qml for full color palette.

### Style System
Access styling through the Style service from `qs.Commons`:
- `Style.capsuleColor`, `Style.radiusM`, `Style.barHeight`
- `Style.marginL`, `Style.marginM`, `Style.marginS`
- `Style.fontSizeL`, `Style.fontSizeM`, `Style.fontSizeXS`
