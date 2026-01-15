import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Widgets
import qs.Services.UI

Rectangle {
    id: root

    // Bar widget properties (injected by Noctalia)
    property var pluginApi: null
    property var screen: null
    property string widgetId: ""
    property string section: ""
    property string barPosition: ""

    // Layout helpers
    readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
    readonly property int iconSize: Style.toOdd(Style.capsuleHeight * 0.65)
    readonly property string menuIconName: "background"

    // Settings
    readonly property int updateInterval: pluginApi?.pluginSettings?.updateInterval ||
                                          pluginApi?.manifest?.metadata?.defaultSettings?.updateInterval ||
                                          3000
    readonly property string displayMode: pluginApi?.pluginSettings?.displayMode ||
                                          pluginApi?.manifest?.metadata?.defaultSettings?.displayMode ||
                                          "full"

    // Computed: count of apps with status messages (for badge)
    readonly property int messageCount: countMessagesIn(backgroundApps)

    function countMessagesIn(apps) {
        var count = 0;
        for (var i = 0; i < apps.length; i++) {
            if (apps[i].message) count++;
        }
        return count;
    }

    // Data
    property var backgroundApps: []

    // Intermediate data for fallback detection
    property var runningFlatpaks: []
    property var windowedApps: []
    property bool portalWorked: false

    // Capsule styling to match built-in widgets
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    implicitHeight: displayMode === "menu" ? Style.capsuleHeight :
                    (barIsVertical ? Math.round(appFlow.implicitHeight) : Style.capsuleHeight)
    implicitWidth: displayMode === "menu" ? Style.capsuleHeight :
                   (barIsVertical ? Style.capsuleHeight : Math.round(appFlow.implicitWidth))

    visible: backgroundApps.length > 0
    opacity: backgroundApps.length > 0 ? 1.0 : 0.0

    Component.onCompleted: {
        portalProcess.running = true;
    }

    // Helper function to get app info from desktop entry
    function getAppInfo(appId) {
        var entry = null;
        var name = appId;

        if (typeof DesktopEntries !== 'undefined') {
            try {
                if (DesktopEntries.heuristicLookup) {
                    entry = DesktopEntries.heuristicLookup(appId);
                }
                if (!entry && DesktopEntries.byId) {
                    entry = DesktopEntries.byId(appId);
                }
                if (entry && entry.name) {
                    name = entry.name;
                }
            } catch (e) {}
        }

        // Use ThemeIcons for proper icon resolution
        var icon = ThemeIcons.iconForAppId(appId);

        return { name: name, icon: icon, entry: entry };
    }

    // Parse portal output for background apps
    function parsePortalOutput(output) {
        var apps = [];
        var regex = /'app_id':\s*<'([^']*)'>/g;
        var match;
        while ((match = regex.exec(output)) !== null) {
            var appId = match[1];
            var escapedAppId = appId.replace(/\./g, '\\.');
            var msgRegex = new RegExp("'app_id':\\s*<'" + escapedAppId + "'>[^}]*'message':\\s*<'([^']*)'>", "g");
            var msgMatch = msgRegex.exec(output);
            apps.push({
                appId: appId,
                message: msgMatch ? msgMatch[1] : ""
            });
        }
        return apps;
    }

    // Parse flatpak ps output
    function parseFlatpakPs(output) {
        var apps = [];
        var lines = output.trim().split('\n');
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            // Format: instance_id pid app_id runtime
            var parts = line.split(/\s+/);
            if (parts.length >= 3) {
                apps.push(parts[2]); // app_id is third column
            }
        }
        return apps;
    }

    // Parse niri msg windows output for app IDs
    function parseNiriWindows(output) {
        var apps = new Set();
        var regex = /App ID:\s*"([^"]+)"/g;
        var match;
        while ((match = regex.exec(output)) !== null) {
            apps.add(match[1]);
        }
        return Array.from(apps);
    }

    // Compute background apps from flatpak ps minus windowed apps
    function computeBackgroundApps() {
        var bgApps = [];
        for (var i = 0; i < runningFlatpaks.length; i++) {
            var appId = runningFlatpaks[i];
            if (windowedApps.indexOf(appId) === -1) {
                bgApps.push({
                    appId: appId,
                    message: ""
                });
            }
        }
        return bgApps;
    }

    // Activate an app
    function activateApp(appId) {
        var info = getAppInfo(appId);
        if (info.entry && info.entry.execute) {
            try {
                info.entry.execute();
            } catch (e) {
                console.log("Background Apps: Failed to execute app:", e);
            }
        }
    }

    // Open panel
    function openPanel() {
        if (!pluginApi) return;

        for (var slotNum = 1; slotNum <= 2; slotNum++) {
            var panelName = "pluginPanel" + slotNum;
            var panel = PanelService.getPanel(panelName, root.screen);

            if (panel && panel.currentPluginId === pluginApi.pluginId) {
                panel.toggle(root);
                return;
            }
        }

        for (var slotNum = 1; slotNum <= 2; slotNum++) {
            var panelName = "pluginPanel" + slotNum;
            var panel = PanelService.getPanel(panelName, root.screen);

            if (panel && panel.currentPluginId === "") {
                panel.currentPluginId = pluginApi.pluginId;
                panel.open(root);
                return;
            }
        }

        var panel1 = PanelService.getPanel("pluginPanel1", root.screen);
        if (panel1) {
            panel1.unloadPluginPanel();
            panel1.currentPluginId = pluginApi.pluginId;
            panel1.open(root);
        }
    }

    // Menu button mode - single icon with badge
    Item {
        id: menuButton
        anchors.fill: parent
        visible: displayMode === "menu"

        NIcon {
            id: menuIcon
            anchors.centerIn: parent
            icon: menuIconName
            pointSize: Style.fontSizeL
            applyUiScale: false
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                TooltipService.hideImmediately();
                root.openPanel();
            }

            onEntered: {
                var tooltip = root.backgroundApps.length + " background app" +
                              (root.backgroundApps.length !== 1 ? "s" : "");
                TooltipService.show(menuIcon, tooltip, BarService.getTooltipDirection());
            }

            onExited: TooltipService.hide()
        }

        // Notification badge (visible when apps have status messages)
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 2
            anchors.topMargin: 1
            z: 2
            height: 8
            width: height
            radius: Style.radiusXS
            color: Color.mError
            border.color: Color.mSurface
            border.width: Style.borderS
            visible: root.messageCount > 0
        }
    }

    // Full mode - all app icons
    Flow {
        id: appFlow

        anchors.centerIn: parent
        spacing: Style.marginXS
        flow: barIsVertical ? Flow.TopToBottom : Flow.LeftToRight
        visible: displayMode === "full"

        Repeater {
            model: root.backgroundApps

            delegate: Item {
                required property var modelData
                required property int index

                width: Style.capsuleHeight
                height: Style.capsuleHeight

                IconImage {
                    id: appIcon

                    property var appInfo: root.getAppInfo(modelData.appId)

                    width: iconSize
                    height: iconSize
                    anchors.centerIn: parent
                    asynchronous: true
                    source: appInfo.icon

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: function(mouse) {
                            TooltipService.hideImmediately();
                            if (mouse.button === Qt.LeftButton) {
                                root.activateApp(modelData.appId);
                            } else if (mouse.button === Qt.RightButton) {
                                root.openPanel();
                            }
                        }

                        onEntered: {
                            var tooltip = appIcon.appInfo.name;
                            if (modelData.message) {
                                tooltip += "\n" + modelData.message;
                            }
                            TooltipService.show(appIcon, tooltip, BarService.getTooltipDirection());
                        }

                        onExited: TooltipService.hide()
                    }
                }
            }
        }
    }

    // Portal query process (primary method - works on GNOME)
    Process {
        id: portalProcess

        property string collectedOutput: ""

        command: ["gdbus", "call", "--session",
                  "--dest", "org.freedesktop.background.Monitor",
                  "--object-path", "/org/freedesktop/background/monitor",
                  "--method", "org.freedesktop.DBus.Properties.Get",
                  "org.freedesktop.background.Monitor", "BackgroundApps"]

        stdout: SplitParser {
            onRead: function(data) {
                portalProcess.collectedOutput += data;
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && collectedOutput) {
                var apps = root.parsePortalOutput(collectedOutput);
                if (apps.length > 0) {
                    root.portalWorked = true;
                    root.backgroundApps = apps;
                    collectedOutput = "";
                    return;
                }
            }
            collectedOutput = "";
            // Portal returned empty - try fallback method
            flatpakProcess.running = true;
        }
    }

    // Fallback: Get running Flatpak instances
    Process {
        id: flatpakProcess

        property string collectedOutput: ""

        command: ["flatpak", "ps", "--columns=instance,pid,application,runtime"]

        stdout: SplitParser {
            onRead: function(data) {
                flatpakProcess.collectedOutput += data + "\n";
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && collectedOutput) {
                root.runningFlatpaks = root.parseFlatpakPs(collectedOutput);
            } else {
                root.runningFlatpaks = [];
            }
            collectedOutput = "";
            // Now get windowed apps from niri
            niriProcess.running = true;
        }
    }

    // Fallback: Get windows from niri
    Process {
        id: niriProcess

        property string collectedOutput: ""

        command: ["niri", "msg", "windows"]

        stdout: SplitParser {
            onRead: function(data) {
                niriProcess.collectedOutput += data + "\n";
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && collectedOutput) {
                root.windowedApps = root.parseNiriWindows(collectedOutput);
            } else {
                root.windowedApps = [];
            }
            collectedOutput = "";
            // Compute background apps
            root.backgroundApps = root.computeBackgroundApps();
        }
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: true

        onTriggered: {
            // If portal worked before, try it again; otherwise go straight to fallback
            if (root.portalWorked) {
                portalProcess.running = true;
            } else {
                flatpakProcess.running = true;
            }
        }
    }
}
