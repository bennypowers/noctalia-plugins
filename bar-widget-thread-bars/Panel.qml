import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property var screen: null

    // SmartPanel properties
    readonly property var geometryPlaceholder: panelContainer
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: content.implicitHeight + (Style.marginL * 4)

    // Settings
    readonly property int updateInterval: pluginApi?.pluginSettings?.updateInterval ||
                                          pluginApi?.manifest?.metadata?.defaultSettings?.updateInterval ||
                                          2000

    // Stats properties
    property real cpuUsage: 0
    property list<real> coreUsages: []
    property var topProcesses: []

    // Temp data collectors
    property list<real> tempCoreData: []
    property var tempProcessData: []

    anchors.fill: parent

    Component.onCompleted: {
        console.log("CPU Thread Bars Panel: Loading");
        cpuProcess.running = true;
        coreProcess.running = true;
        topProcessesProcess.running = true;
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: Color.transparent

        Rectangle {
            anchors.fill: parent
            anchors.margins: Style.marginL
            color: Color.mSurface
            radius: Style.radiusL

            ColumnLayout {
                id: content
                x: Style.marginL
                y: Style.marginL
                width: parent.width - (Style.marginL * 2)
                spacing: Style.marginM

                // Header
                NText {
                    Layout.fillWidth: true
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeL
                    text: "CPU Monitor"
                }

                // Overall CPU Usage
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    NText {
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeXS
                        text: "OVERALL CPU"
                    }

                    NText {
                        font.weight: Style.fontWeightBold
                        pointSize: Style.fontSizeL + 6
                        text: `${Math.round(root.cpuUsage)}%`
                    }
                }

                // Per-core usage
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    NText {
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeM
                        text: "Per-Core Usage"
                    }

                    Grid {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: Style.marginM
                        rowSpacing: Style.marginS

                        Repeater {
                            model: root.coreUsages.length

                            delegate: RowLayout {
                                required property int index

                                spacing: 4

                                NText {
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeS
                                    text: `${index}:`
                                    Layout.minimumWidth: 20
                                }

                                NText {
                                    property real usage: index < root.coreUsages.length ? root.coreUsages[index] : 0
                                    property color usageColor: {
                                        if (usage < 25)
                                            return Color.mPrimary;
                                        else if (usage < 50)
                                            return Color.mSecondary;
                                        else if (usage < 75)
                                            return Color.mTertiary;
                                        else
                                            return Color.mError;
                                    }

                                    color: usageColor
                                    pointSize: Style.fontSizeS
                                    text: `${Math.round(usage)}%`
                                    Layout.minimumWidth: 35
                                }
                            }
                        }
                    }
                }

                // Top Processes
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    NText {
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeM
                        text: "Top Processes"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginXS

                        Repeater {
                            model: root.topProcesses

                            delegate: RowLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: Style.marginS

                                NText {
                                    property color cpuColor: {
                                        var cpu = parseFloat(modelData.cpu);
                                        if (cpu < 25)
                                            return Color.mPrimary;
                                        else if (cpu < 50)
                                            return Color.mSecondary;
                                        else if (cpu < 75)
                                            return Color.mTertiary;
                                        else
                                            return Color.mError;
                                    }

                                    color: cpuColor
                                    pointSize: Style.fontSizeS
                                    text: `${modelData.cpu}%`
                                    Layout.minimumWidth: 45
                                    horizontalAlignment: Text.AlignRight
                                }

                                NText {
                                    color: Color.mOnSurfaceVariant
                                    pointSize: Style.fontSizeXS
                                    text: modelData.user
                                    Layout.minimumWidth: 60
                                    elide: Text.ElideRight
                                }

                                NText {
                                    Layout.fillWidth: true
                                    pointSize: Style.fontSizeS
                                    text: modelData.command
                                    elide: Text.ElideRight
                                }
                            }
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
                            root.cpuUsage = usage;
                        }
                    }
                } catch (e) {
                    console.log("CPU Thread Bars Panel: Error parsing CPU usage:", e);
                }
            }
        }
    }

    // Per-core CPU monitoring process
    Process {
        id: coreProcess

        command: ["bash", "-c", "grep '^cpu[0-9]' /proc/stat > /tmp/cpu_panel1; sleep 1; grep '^cpu[0-9]' /proc/stat > /tmp/cpu_panel2; awk 'NR==FNR{a[NR]=$0; next} {split(a[FNR], old); split($0, new); user_diff = new[2] - old[2]; nice_diff = new[3] - old[3]; sys_diff = new[4] - old[4]; idle_diff = new[5] - old[5]; total_diff = user_diff + nice_diff + sys_diff + idle_diff; cpu_usage = (total_diff - idle_diff) * 100 / total_diff; printf \"%.1f\\n\", cpu_usage}' /tmp/cpu_panel1 /tmp/cpu_panel2"]

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
                    console.log("CPU Thread Bars Panel: Error parsing core usage:", e);
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

    // Top processes by CPU usage
    Process {
        id: topProcessesProcess

        command: ["bash", "-c", "ps aux --sort=-%cpu | awk 'NR>1 {printf \"%s|%s|%s\\n\", $3, $1, $11}' | head -5"]

        stdout: SplitParser {
            onRead: function (data) {
                try {
                    if (data && data.trim()) {
                        const line = data.trim();
                        const parts = line.split("|");
                        if (parts.length === 3) {
                            root.tempProcessData.push({
                                cpu: parts[0],
                                user: parts[1],
                                command: parts[2]
                            });
                        }
                    }
                } catch (e) {
                    console.log("CPU Thread Bars Panel: Error parsing process:", e);
                }
            }
        }

        onExited: {
            if (root.tempProcessData.length > 0) {
                root.topProcesses = root.tempProcessData.slice();
                root.tempProcessData = [];
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
            topProcessesProcess.running = true;
        }
    }
}
