import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Modules.DesktopWidgets

DraggableDesktopWidget {
    id: cpuBarWidget

    // Plugin API property (injected by Noctalia)
    property var pluginApi: null

    // Settings (with defaults)
    readonly property string layout: pluginApi?.pluginSettings?.layout ||
                                     pluginApi?.manifest?.metadata?.defaultSettings?.layout ||
                                     "vertical"
    readonly property string verticalDirection: pluginApi?.pluginSettings?.verticalDirection ||
                                                pluginApi?.manifest?.metadata?.defaultSettings?.verticalDirection ||
                                                "ltr"
    readonly property string horizontalDirection: pluginApi?.pluginSettings?.horizontalDirection ||
                                                  pluginApi?.manifest?.metadata?.defaultSettings?.horizontalDirection ||
                                                  "ttb"

    // Bar appearance
    property int barHeight: 3
    property int barSpacing: 2
    property list<real> coreUsages: []
    property real cpuUsage: 0
    property int maxBarWidth: 52
    property bool popoverVisible: false
    property int ramBarHeight: 6
    property int ramGap: 8
    property real ramTotal: 0
    property real ramUsage: 0
    property real ramUsed: 0
    property list<real> tempCoreData: []
    property int updateInterval: 2000

    // Usage level colors - using Noctalia's semantic color system
    readonly property color lowUsageColor: Color.mPrimary          // Low usage - good state
    readonly property color mediumUsageColor: Color.mSecondary     // Medium usage
    readonly property color highUsageColor: Color.mTertiary        // High usage - warning
    readonly property color criticalUsageColor: Color.mError       // Critical usage - alert

    // Auto-size based on core count and layout
    implicitHeight: {
        if (coreUsages.length === 0)
            return Math.round(60 * widgetScale);

        if (layout === "horizontal") {
            // Horizontal: height is bar length, width is number of bars
            return Math.round((maxBarWidth + 16) * widgetScale);
        } else {
            // Vertical: height is number of bars, width is bar length
            var cpuBarsHeight = coreUsages.length * (barHeight + barSpacing);
            return Math.round((cpuBarsHeight + ramGap + ramBarHeight + 8) * widgetScale);
        }
    }

    implicitWidth: {
        if (coreUsages.length === 0)
            return Math.round(60 * widgetScale);

        if (layout === "horizontal") {
            // Horizontal: width is number of bars
            var cpuBarsWidth = coreUsages.length * (barHeight + barSpacing);
            return Math.round((cpuBarsWidth + ramGap + ramBarHeight + 8) * widgetScale);
        } else {
            // Vertical: width is bar length
            return Math.round((maxBarWidth + 16) * widgetScale);
        }
    }

    Component.onCompleted: {
        console.log("CPU Thread Bars widget loaded");
        cpuProcess.running = true;
        coreProcess.running = true;
        ramProcess.running = true;
        ramDetailsProcess.running = true;
    }

    // Background container
    Rectangle {
        anchors.fill: parent
        color: Color.mSurface
        opacity: 0.9
        radius: Math.round(8 * widgetScale)
    }

    // Main layout - switches between Row and Column based on layout setting
    Loader {
        anchors.centerIn: parent
        sourceComponent: layout === "horizontal" ? horizontalLayout : verticalLayout
    }

    // Vertical layout component
    Component {
        id: verticalLayout

        Column {
            spacing: 0
            width: Math.round(maxBarWidth * widgetScale)

            // CPU bars
            Column {
                spacing: Math.round(barSpacing * widgetScale)
                width: Math.round(maxBarWidth * widgetScale)

                Repeater {
                    model: cpuBarWidget.coreUsages.length

                    delegate: Item {
                        required property int index

                        height: Math.round(barHeight * widgetScale)
                        width: Math.round(maxBarWidth * widgetScale)

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
                            property real usage: index < cpuBarWidget.coreUsages.length ? cpuBarWidget.coreUsages[index] : 0
                            property color usageColor: {
                                if (usage < 25)
                                    return cpuBarWidget.lowUsageColor;
                                else if (usage < 50)
                                    return cpuBarWidget.mediumUsageColor;
                                else if (usage < 75)
                                    return cpuBarWidget.highUsageColor;
                                else
                                    return cpuBarWidget.criticalUsageColor;
                            }

                            // Direction-based anchoring
                            anchors.left: verticalDirection === "rtl" ? undefined : parent.left
                            anchors.leftMargin: verticalDirection === "rtl" ? 0 : Math.round(widgetScale)
                            anchors.right: verticalDirection === "ltr" ? undefined : parent.right
                            anchors.rightMargin: verticalDirection === "ltr" ? 0 : Math.round(widgetScale)
                            anchors.verticalCenter: parent.verticalCenter

                            color: usageColor
                            height: Math.round((barHeight - 2) * widgetScale)
                            radius: Math.round(widgetScale)
                            width: Math.max(Math.round(2 * widgetScale), Math.round((maxBarWidth - 2) * widgetScale * (usage / 100)))

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
                                }
                            }
                            Behavior on width {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }
                }
            }

            // Gap before RAM bar
            Item {
                height: Math.round(ramGap * widgetScale)
                width: Math.round(maxBarWidth * widgetScale)
            }

            // RAM bar
            Item {
                height: Math.round(ramBarHeight * widgetScale)
                width: Math.round(maxBarWidth * widgetScale)

                // Background bar
                Rectangle {
                    anchors.fill: parent
                    border.color: Color.mOnSurfaceVariant
                    border.width: 1
                    color: "transparent"
                    opacity: 0.3
                    radius: 2
                }

                // Usage bar
                Rectangle {
                    property color ramColor: {
                        if (ramUsage < 25)
                            return cpuBarWidget.lowUsageColor;
                        else if (ramUsage < 50)
                            return cpuBarWidget.mediumUsageColor;
                        else if (ramUsage < 75)
                            return cpuBarWidget.highUsageColor;
                        else
                            return cpuBarWidget.criticalUsageColor;
                    }

                    // Direction-based anchoring
                    anchors.left: verticalDirection === "rtl" ? undefined : parent.left
                    anchors.leftMargin: verticalDirection === "rtl" ? 0 : Math.round(widgetScale)
                    anchors.right: verticalDirection === "ltr" ? undefined : parent.right
                    anchors.rightMargin: verticalDirection === "ltr" ? 0 : Math.round(widgetScale)
                    anchors.verticalCenter: parent.verticalCenter

                    color: ramColor
                    height: Math.round((ramBarHeight - 2) * widgetScale)
                    radius: Math.round(2 * widgetScale)
                    width: Math.max(Math.round(2 * widgetScale), Math.round((maxBarWidth - 2) * widgetScale * (ramUsage / 100)))

                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }

    // Horizontal layout component
    Component {
        id: horizontalLayout

        Row {
            spacing: 0
            height: Math.round(maxBarWidth * widgetScale)

            // CPU bars
            Row {
                spacing: Math.round(barSpacing * widgetScale)
                height: Math.round(maxBarWidth * widgetScale)

                Repeater {
                    model: cpuBarWidget.coreUsages.length

                    delegate: Item {
                        required property int index

                        width: Math.round(barHeight * widgetScale)
                        height: Math.round(maxBarWidth * widgetScale)

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
                            property real usage: index < cpuBarWidget.coreUsages.length ? cpuBarWidget.coreUsages[index] : 0
                            property color usageColor: {
                                if (usage < 25)
                                    return cpuBarWidget.lowUsageColor;
                                else if (usage < 50)
                                    return cpuBarWidget.mediumUsageColor;
                                else if (usage < 75)
                                    return cpuBarWidget.highUsageColor;
                                else
                                    return cpuBarWidget.criticalUsageColor;
                            }

                            // Direction-based anchoring
                            anchors.top: horizontalDirection === "btt" ? undefined : parent.top
                            anchors.topMargin: horizontalDirection === "btt" ? 0 : Math.round(widgetScale)
                            anchors.bottom: horizontalDirection === "ttb" ? undefined : parent.bottom
                            anchors.bottomMargin: horizontalDirection === "ttb" ? 0 : Math.round(widgetScale)
                            anchors.horizontalCenter: parent.horizontalCenter

                            color: usageColor
                            width: Math.round((barHeight - 2) * widgetScale)
                            radius: Math.round(widgetScale)
                            height: Math.max(Math.round(2 * widgetScale), Math.round((maxBarWidth - 2) * widgetScale * (usage / 100)))

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

            // Gap before RAM bar
            Item {
                width: Math.round(ramGap * widgetScale)
                height: Math.round(maxBarWidth * widgetScale)
            }

            // RAM bar
            Item {
                width: Math.round(ramBarHeight * widgetScale)
                height: Math.round(maxBarWidth * widgetScale)

                // Background bar
                Rectangle {
                    anchors.fill: parent
                    border.color: Color.mOnSurfaceVariant
                    border.width: 1
                    color: "transparent"
                    opacity: 0.3
                    radius: 2
                }

                // Usage bar
                Rectangle {
                    property color ramColor: {
                        if (ramUsage < 25)
                            return cpuBarWidget.lowUsageColor;
                        else if (ramUsage < 50)
                            return cpuBarWidget.mediumUsageColor;
                        else if (ramUsage < 75)
                            return cpuBarWidget.highUsageColor;
                        else
                            return cpuBarWidget.criticalUsageColor;
                    }

                    // Direction-based anchoring
                    anchors.top: horizontalDirection === "btt" ? undefined : parent.top
                    anchors.topMargin: horizontalDirection === "btt" ? 0 : Math.round(widgetScale)
                    anchors.bottom: horizontalDirection === "ttb" ? undefined : parent.bottom
                    anchors.bottomMargin: horizontalDirection === "ttb" ? 0 : Math.round(widgetScale)
                    anchors.horizontalCenter: parent.horizontalCenter

                    color: ramColor
                    width: Math.round((ramBarHeight - 2) * widgetScale)
                    radius: Math.round(2 * widgetScale)
                    height: Math.max(Math.round(2 * widgetScale), Math.round((maxBarWidth - 2) * widgetScale * (ramUsage / 100)))

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
                            cpuBarWidget.cpuUsage = usage;
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
                            cpuBarWidget.tempCoreData.push(usage);
                        }
                    }
                } catch (e) {
                    console.log("CPU Thread Bars: Error parsing core usage:", e);
                }
            }
        }

        onExited: {
            if (cpuBarWidget.tempCoreData.length > 0) {
                cpuBarWidget.coreUsages = cpuBarWidget.tempCoreData.slice();
                cpuBarWidget.tempCoreData = [];
            }
        }
    }

    // RAM monitoring process
    Process {
        id: ramProcess

        command: ["bash", "-c", "free | grep Mem | awk '{print ($3/$2) * 100.0}'"]

        stdout: SplitParser {
            onRead: function (data) {
                try {
                    if (data && data.trim()) {
                        const usage = parseFloat(data.trim());
                        if (!isNaN(usage)) {
                            cpuBarWidget.ramUsage = usage;
                        }
                    }
                } catch (e) {
                    console.log("CPU Thread Bars: Error parsing RAM usage:", e);
                }
            }
        }
    }

    // RAM details process (total, used in MB)
    Process {
        id: ramDetailsProcess

        command: ["bash", "-c", "free -m | grep Mem | awk '{print $2\" \"$3}'"]

        stdout: SplitParser {
            onRead: function (data) {
                try {
                    if (data && data.trim()) {
                        const parts = data.trim().split(" ");
                        if (parts.length === 2) {
                            cpuBarWidget.ramTotal = parseFloat(parts[0]);
                            cpuBarWidget.ramUsed = parseFloat(parts[1]);
                        }
                    }
                } catch (e) {
                    console.log("CPU Thread Bars: Error parsing RAM details:", e);
                }
            }
        }
    }

    Timer {
        interval: cpuBarWidget.updateInterval
        repeat: true
        running: true

        onTriggered: {
            cpuProcess.running = true;
            coreProcess.running = true;
            ramProcess.running = true;
            ramDetailsProcess.running = true;
        }
    }
}
