import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    // Settings
    readonly property int updateInterval: pluginApi?.pluginSettings?.updateInterval ||
                                          pluginApi?.manifest?.metadata?.defaultSettings?.updateInterval ||
                                          2000

    // Bar appearance
    property int barHeight: 3
    property int barSpacing: 2
    property int maxBarWidth: 20

    // Stats data
    property list<real> coreUsages: []
    property real cpuUsage: 0
    property list<real> tempCoreData: []

    // Usage level colors - using Noctalia's semantic color system
    readonly property color lowUsageColor: Color.mPrimary
    readonly property color mediumUsageColor: Color.mSecondary
    readonly property color highUsageColor: Color.mTertiary
    readonly property color criticalUsageColor: Color.mError

    // Capsule styling to match built-in widgets
    radius: Style.radiusS
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    implicitHeight: barIsVertical ? Math.round(contentColumn.implicitHeight + Style.marginS * 2) : Style.capsuleHeight
    implicitWidth: barIsVertical ? Style.capsuleHeight : Math.round(contentColumn.implicitWidth + Style.marginM * 2)

    Component.onCompleted: {
        console.log("CPU Thread Bars bar widget loaded");
        cpuProcess.running = true;
        coreProcess.running = true;
    }

    // Main content - CPU thread bars
    Row {
        id: contentColumn

        anchors.centerIn: parent
        spacing: barSpacing

        Repeater {
            model: root.coreUsages.length

            delegate: Item {
                required property int index

                width: barHeight
                height: maxBarWidth

                // Background bar
                Rectangle {
                    anchors.fill: parent
                    border.color: Color.mOnSurfaceVariant
                    border.width: 1
                    color: "transparent"
                    opacity: 0.3
                    radius: 1
                }

                // Usage bar
                Rectangle {
                    property real usage: index < root.coreUsages.length ? root.coreUsages[index] : 0
                    property color usageColor: {
                        if (usage < 25)
                            return root.lowUsageColor;
                        else if (usage < 50)
                            return root.mediumUsageColor;
                        else if (usage < 75)
                            return root.highUsageColor;
                        else
                            return root.criticalUsageColor;
                    }

                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter

                    color: usageColor
                    width: barHeight - 2
                    radius: 1
                    height: Math.max(2, (maxBarWidth - 2) * (usage / 100))

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }

    // Click to open panel
    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!pluginApi) return;

            // Try to find an existing panel slot showing this plugin
            var panelFound = false;
            for (var slotNum = 1; slotNum <= 2; slotNum++) {
                var panelName = "pluginPanel" + slotNum;
                var panel = PanelService.getPanel(panelName, root.screen);

                if (panel && panel.currentPluginId === pluginApi.pluginId) {
                    // Panel already open, toggle it with widget anchor
                    panel.toggle(root);
                    panelFound = true;
                    break;
                }
            }

            // If panel not found, open it in an available slot
            if (!panelFound) {
                for (var slotNum = 1; slotNum <= 2; slotNum++) {
                    var panelName = "pluginPanel" + slotNum;
                    var panel = PanelService.getPanel(panelName, root.screen);

                    if (panel && panel.currentPluginId === "") {
                        // Empty slot found - load this plugin and open with widget anchor
                        panel.currentPluginId = pluginApi.pluginId;
                        panel.open(root);
                        panelFound = true;
                        break;
                    }
                }
            }

            // If both slots occupied, replace slot 1
            if (!panelFound) {
                var panel1 = PanelService.getPanel("pluginPanel1", root.screen);
                if (panel1) {
                    panel1.unloadPluginPanel();
                    panel1.currentPluginId = pluginApi.pluginId;
                    panel1.open(root);
                }
            }
        }
    }

    // Overall CPU monitoring process
    Process {
        id: cpuProcess

        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print 100 - $1}'"]

        stdout: SplitParser {
            onRead: function (data) {
                try {
                    if (data && data.trim()) {
                        const usage = parseFloat(data.trim());
                        if (!isNaN(usage)) {
                            root.cpuUsage = usage;
                        }
                    }
                } catch (e) {
                    console.log("CPU Thread Bars: Error parsing CPU usage:", e);
                }
            }
        }
    }

    // Per-core CPU monitoring process
    Process {
        id: coreProcess

        command: ["bash", "-c", "grep '^cpu[0-9]' /proc/stat > /tmp/cpu1; sleep 1; grep '^cpu[0-9]' /proc/stat > /tmp/cpu2; awk 'NR==FNR{a[NR]=$0; next} {split(a[FNR], old); split($0, new); user_diff = new[2] - old[2]; nice_diff = new[3] - old[3]; sys_diff = new[4] - old[4]; idle_diff = new[5] - old[5]; total_diff = user_diff + nice_diff + sys_diff + idle_diff; cpu_usage = (total_diff - idle_diff) * 100 / total_diff; printf \"%.1f\\n\", cpu_usage}' /tmp/cpu1 /tmp/cpu2"]

        stdout: SplitParser {
            onRead: function (data) {
                try {
                    if (data && data.trim()) {
                        const usage = parseFloat(data.trim());
                        if (!isNaN(usage)) {
                            root.tempCoreData.push(usage);
                        }
                    }
                } catch (e) {
                    console.log("CPU Thread Bars: Error parsing core usage:", e);
                }
            }
        }

        onExited: {
            if (root.tempCoreData.length > 0) {
                root.coreUsages = root.tempCoreData.slice();
                root.tempCoreData = [];
            }
        }
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: true

        onTriggered: {
            cpuProcess.running = true;
            coreProcess.running = true;
        }
    }
}
