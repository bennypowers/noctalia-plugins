import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property var screen: null

    // SmartPanel properties
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 350 * Style.uiScaleRatio
    property real contentPreferredHeight: content.implicitHeight + (Style.marginL * 2)

    // Settings
    readonly property int updateInterval: pluginApi?.pluginSettings?.updateInterval ||
                                          pluginApi?.manifest?.metadata?.defaultSettings?.updateInterval ||
                                          3000

    // Data
    property var backgroundApps: []

    // Intermediate data for fallback detection
    property var runningFlatpaks: []
    property var windowedApps: []
    property bool portalWorked: false

    anchors.fill: parent

    Component.onCompleted: {
        console.log("Background Apps Panel: Loading");
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
            var parts = line.split(/\s+/);
            if (parts.length >= 3) {
                apps.push(parts[2]);
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
                console.log("Background Apps Panel: Failed to execute app:", e);
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        // Header
        NText {
            Layout.fillWidth: true
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            text: "Background Apps"
        }

        // Empty state
        NText {
            Layout.fillWidth: true
            visible: root.backgroundApps.length === 0
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeM
            text: "No background apps running"
        }

        // App list
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            visible: root.backgroundApps.length > 0

            Repeater {
                model: root.backgroundApps

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    height: appRow.implicitHeight + Style.marginS * 2
                    color: mouseArea.containsMouse ? Color.mSurfaceVariant : "transparent"
                    radius: Style.radiusM

                    property var appInfo: root.getAppInfo(modelData.appId)

                    RowLayout {
                        id: appRow
                        anchors.fill: parent
                        anchors.margins: Style.marginS
                        spacing: Style.marginM

                        IconImage {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            source: appInfo.icon
                            asynchronous: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            NText {
                                Layout.fillWidth: true
                                pointSize: Style.fontSizeM
                                text: appInfo.name
                                elide: Text.ElideRight
                            }

                            NText {
                                Layout.fillWidth: true
                                visible: modelData.message && modelData.message.length > 0
                                color: Color.mOnSurfaceVariant
                                pointSize: Style.fontSizeS
                                text: modelData.message || ""
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.activateApp(modelData.appId);
                        }
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
            root.backgroundApps = root.computeBackgroundApps();
        }
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: true

        onTriggered: {
            if (root.portalWorked) {
                portalProcess.running = true;
            } else {
                flatpakProcess.running = true;
            }
        }
    }
}
