import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Rectangle {
    id: cpuBarWidget

    // Required properties for Noctalia desktop widget
    required property var pluginApi
    required property var screen
    required property string widgetId

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

    color: Color.transparent

    // Auto-size based on core count
    implicitHeight: {
        if (coreUsages.length === 0)
            return 60;
        var cpuBarsHeight = coreUsages.length * (barHeight + barSpacing);
        return cpuBarsHeight + ramGap + ramBarHeight + 8;
    }
    implicitWidth: maxBarWidth + 16
    radius: 8

    Component.onCompleted: {
        console.log("CPU Thread Bars widget loaded");
        cpuProcess.running = true;
        coreProcess.running = true;
        ramProcess.running = true;
        ramDetailsProcess.running = true;
    }

    Column {
        anchors.centerIn: parent
        spacing: 0
        width: maxBarWidth

        // CPU bars
        Column {
            spacing: barSpacing
            width: maxBarWidth

            Repeater {
                model: cpuBarWidget.coreUsages.length

                delegate: Item {
                    required property int index

                    height: barHeight
                    width: maxBarWidth

                    // Background bar
                    Rectangle {
                        anchors.fill: parent
                        border.color: Color.mOnSurfaceVariant
                        border.width: 1
                        color: Color.transparent
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

                        anchors.right: parent.right
                        anchors.rightMargin: 1
                        anchors.verticalCenter: parent.verticalCenter
                        color: usageColor
                        height: barHeight - 2
                        radius: 1
                        width: Math.max(2, (maxBarWidth - 2) * (usage / 100))

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
            height: ramGap
            width: maxBarWidth
        }

        // RAM bar
        Item {
            height: ramBarHeight
            width: maxBarWidth

            // Background bar
            Rectangle {
                anchors.fill: parent
                border.color: Color.mOnSurfaceVariant
                border.width: 1
                color: Color.transparent
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

                anchors.right: parent.right
                anchors.rightMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                color: ramColor
                height: ramBarHeight - 2
                radius: 2
                width: Math.max(2, (maxBarWidth - 2) * (ramUsage / 100))

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
