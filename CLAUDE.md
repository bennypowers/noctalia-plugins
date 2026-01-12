## Adding a New Plugin

- See ./.github/workflows/README.md for instructions
- see /etc/xdg/quickshell/noctalia-shell/ for upstream widgets and usage
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

### Desktop Widgets
Desktop widgets must:
1. Import `qs.Modules.DesktopWidgets`
2. Extend `DraggableDesktopWidget` (not Rectangle or Item)
3. Declare `property var pluginApi: null` (injected by Noctalia, not required)
4. Define `implicitWidth` and `implicitHeight`
5. Scale all dimensions by `widgetScale` property (provided by DraggableDesktopWidget)

Example:
```qml
import qs.Modules.DesktopWidgets

DraggableDesktopWidget {
    property var pluginApi: null  // Injected by system

    implicitWidth: Math.round(baseWidth * widgetScale)
    implicitHeight: Math.round(baseHeight * widgetScale)

    // Content here - scale all dimensions by widgetScale
}
```

**IMPORTANT**:
- Desktop widgets automatically receive `widgetScale`, `widgetData`, `isDragging`, and `isScaling` properties from DraggableDesktopWidget
- `pluginApi` is NOT a required property - declare it as `property var pluginApi: null` and it will be injected by Noctalia
- Use optional chaining (`pluginApi?.settingName`) when accessing pluginApi to handle null safely

### Bar Widget Properties
Bar widgets must declare (properties are injected by Noctalia, not required):
```qml
property var pluginApi: null
property var screen: null
property string widgetId: ""
property string section: ""
property string barPosition: ""
```

**IMPORTANT**: Like desktop widgets, bar widget properties are injected at runtime and should NOT use the `required` keyword.

### Color System
Access colors through the Color service from `qs.Commons`:
- `Color.mPrimary`, `Color.mSecondary`, `Color.mTertiary` - Accent colors
- `Color.mError` - Error/critical state color
- `Color.mOnSurface`, `Color.mOnSurfaceVariant` - Text colors
- `Color.mSurface`, `Color.mSurfaceVariant` - Background colors
- `Color.mOutline` - Border colors

**Note:** Use Qt color strings like `"transparent"`, `"black"`, `"white"` for absolute colors (not `Color.transparent` etc.)

See https://github.com/noctalia-dev/noctalia-shell/blob/main/Commons/Color.qml for full color palette.

### Style System
Access styling through the Style service from `qs.Commons`:
- `Style.capsuleColor`, `Style.radiusM`, `Style.barHeight`
- `Style.marginL`, `Style.marginM`, `Style.marginS`
- `Style.fontSizeL`, `Style.fontSizeM`, `Style.fontSizeXS`
