import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    // Bar widget properties (injected by Noctalia)
    property var pluginApi: null
    property var screen: null
    property string widgetId: ""
    property string section: ""
    property string barPosition: ""

    // Layout helpers
    readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
    readonly property string screenName: screen ? screen.name : ""
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)

    // Settings
    readonly property int updateInterval: pluginApi?.pluginSettings?.updateInterval ||
                                          pluginApi?.manifest?.metadata?.defaultSettings?.updateInterval ||
                                          5000
    readonly property string configuredUpsName: pluginApi?.pluginSettings?.upsName || ""
    readonly property bool showPowerDraw: pluginApi?.pluginSettings?.showPowerDraw ||
                                          pluginApi?.manifest?.metadata?.defaultSettings?.showPowerDraw ||
                                          false
    readonly property bool showBatteryOnlyOnBattery: pluginApi?.pluginSettings?.showBatteryOnlyOnBattery ||
                                                     pluginApi?.manifest?.metadata?.defaultSettings?.showBatteryOnlyOnBattery ||
                                                     false
    readonly property string batteryColor: pluginApi?.pluginSettings?.batteryColor ||
                                           pluginApi?.manifest?.metadata?.defaultSettings?.batteryColor ||
                                           "auto"
    readonly property real powerFactor: pluginApi?.pluginSettings?.powerFactor ||
                                        pluginApi?.manifest?.metadata?.defaultSettings?.powerFactor ||
                                        0.6

    // Auto-detected or configured UPS name
    property string detectedUpsName: ""
    readonly property string activeUpsName: configuredUpsName || detectedUpsName

    // UPS data
    property int batteryCharge: -1
    property string upsStatus: ""
    property real powerDraw: -1
    property bool powerDrawEstimated: false
    property bool upsAvailable: false

    // Status parsing
    readonly property bool isOnline: upsStatus.indexOf("OL") >= 0
    readonly property bool isOnBattery: upsStatus.indexOf("OB") >= 0
    readonly property bool isLowBattery: upsStatus.indexOf("LB") >= 0
    readonly property bool isCharging: upsStatus.indexOf("CHRG") >= 0

    // Icon selection based on charge level and status
    readonly property string batteryIcon: {
        if (!upsAvailable) return "battery-off";
        if (isLowBattery) return "battery-exclamation";
        if (batteryCharge < 0) return "battery-off";
        if (isCharging) return "battery-charging";
        if (batteryCharge <= 20) return "battery-1";
        if (batteryCharge <= 40) return "battery-2";
        if (batteryCharge <= 60) return "battery-3";
        if (batteryCharge <= 80) return "battery-4";
        return "battery";
    }

    // Status color
    readonly property color statusColor: {
        if (!upsAvailable) return Color.mOnSurfaceVariant;
        if (isLowBattery) return Color.mError;
        if (isOnBattery) {
            if (batteryColor === "auto") return Color.mTertiary;
            if (batteryColor === "tertiary") return Color.mTertiary;
            if (batteryColor === "warning") return "#ffb300";
            if (batteryColor === "error") return Color.mError;
            if (batteryColor === "primary") return Color.mPrimary;
            if (batteryColor === "onsurface") return Color.mOnSurface;
            return Color.mTertiary;
        }
        if (batteryCharge <= 20) return Color.mError;
        if (batteryCharge <= 40) return Color.mTertiary;
        return Color.mOnSurface;
    }

    // Show battery percentage based on setting
    readonly property bool showBatteryCharge: {
        if (!showBatteryOnlyOnBattery) return batteryCharge >= 0;
        return batteryCharge >= 0 && isOnBattery;
    }

    // Content dimensions for implicit sizing
    readonly property real contentWidth: barIsVertical ? capsuleHeight : Math.round(contentRow.implicitWidth + Style.marginM * 2)
    readonly property real contentHeight: barIsVertical ? Math.round(contentRow.implicitHeight + Style.marginS * 2) : capsuleHeight

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    visible: upsAvailable

    Component.onCompleted: {
        console.log("NUT Status bar widget loaded");
        startQuery();
    }

    // Re-query when activeUpsName becomes available (handles late pluginApi injection)
    onActiveUpsNameChanged: {
        if (activeUpsName && !upsAvailable) {
            upsProcess.running = true;
        }
    }

    function startQuery() {
        // Auto-detect UPS if not configured
        if (!configuredUpsName) {
            upsListProcess.running = true;
        } else if (activeUpsName) {
            upsProcess.running = true;
        }
    }

    NPopupContextMenu {
        id: contextMenu

        model: [
            {
                "label": "Settings",
                "action": "widget-settings",
                "icon": "settings"
            },
        ]

        onTriggered: action => {
            contextMenu.close();
            PanelService.closeContextMenu(screen);

            if (action === "widget-settings") {
                BarService.openPluginSettings(screen, pluginApi?.manifest);
            }
        }
    }

    // Visual capsule
    Rectangle {
        id: capsule
        width: root.contentWidth
        height: root.contentHeight
        anchors.centerIn: parent

        color: Style.capsuleColor
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth
        radius: Style.radiusS

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginXS

            // Battery icon
            NIcon {
                id: batteryIconItem
                icon: root.batteryIcon
                pointSize: Style.fontSizeL
                applyUiScale: false
                color: root.statusColor
            }

            // Charge percentage
            NText {
                visible: root.showBatteryCharge
                text: root.batteryCharge + "%"
                color: root.statusColor
                pointSize: Style.fontSizeM
            }

            // Power draw
            NText {
                visible: root.showPowerDraw && root.powerDraw >= 0
                text: (root.powerDrawEstimated ? "~" : "") + root.powerDraw.toFixed(0) + "W"
                color: root.statusColor
                pointSize: Style.fontSizeXS
            }

            // Status indicator for on-battery
            NIcon {
                visible: root.isOnBattery && !root.isCharging
                icon: "bolt"
                pointSize: Style.fontSizeS
                applyUiScale: false
                color: root.statusColor
            }
        }
    }

    // Click and hover handling
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (mouse.button === Qt.RightButton) {
                PanelService.showContextMenu(contextMenu, root, screen);
            } else {
                TooltipService.hideImmediately();
                openPanel();
            }
        }

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: {
            var tooltip = "UPS: " + root.activeUpsName;
            if (root.batteryCharge >= 0) {
                tooltip += "\nCharge: " + root.batteryCharge + "%";
            }
            if (root.powerDraw >= 0) {
                tooltip += "\nPower: " + (root.powerDrawEstimated ? "~" : "") + root.powerDraw.toFixed(0) + "W";
            }
            if (root.isOnline) {
                tooltip += "\nStatus: Online (AC Power)";
            } else if (root.isOnBattery) {
                tooltip += "\nStatus: On Battery";
            }
            if (root.isCharging) {
                tooltip += " (Charging)";
            }
            if (root.isLowBattery) {
                tooltip += "\nLow Battery!";
            }
            TooltipService.show(capsule, tooltip, BarService.getTooltipDirection());
        }

        onExited: TooltipService.hide()
    }

    function openPanel() {
        if (!pluginApi) return;

        // Try to find an existing panel slot showing this plugin
        for (var slotNum = 1; slotNum <= 2; slotNum++) {
            var panelName = "pluginPanel" + slotNum;
            var panel = PanelService.getPanel(panelName, root.screen);

            if (panel && panel.currentPluginId === pluginApi.pluginId) {
                panel.toggle(root);
                return;
            }
        }

        // If panel not found, open it in an available slot
        for (var slotNum = 1; slotNum <= 2; slotNum++) {
            var panelName = "pluginPanel" + slotNum;
            var panel = PanelService.getPanel(panelName, root.screen);

            if (panel && panel.currentPluginId === "") {
                panel.currentPluginId = pluginApi.pluginId;
                panel.open(root);
                return;
            }
        }

        // If both slots occupied, replace slot 1
        var panel1 = PanelService.getPanel("pluginPanel1", root.screen);
        if (panel1) {
            panel1.unloadPluginPanel();
            panel1.currentPluginId = pluginApi.pluginId;
            panel1.open(root);
        }
    }

    // UPS list process for auto-detection
    Process {
        id: upsListProcess

        property string collectedOutput: ""

        command: ["upsc", "-l"]

        stdout: SplitParser {
            onRead: function(data) {
                upsListProcess.collectedOutput += data + "\n";
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && collectedOutput) {
                var lines = collectedOutput.trim().split('\n');
                if (lines.length > 0 && lines[0].trim()) {
                    root.detectedUpsName = lines[0].trim();
                    console.log("NUT Status: Auto-detected UPS:", root.detectedUpsName);
                    upsProcess.running = true;
                }
            }
            collectedOutput = "";
        }
    }

    // UPS query process
    Process {
        id: upsProcess

        property string collectedOutput: ""

        command: ["upsc", root.activeUpsName]

        stdout: SplitParser {
            onRead: function(data) {
                upsProcess.collectedOutput += data + "\n";
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && collectedOutput) {
                root.upsAvailable = true;
                root.parseUpsOutput(collectedOutput);
            } else {
                root.upsAvailable = false;
                root.batteryCharge = -1;
                root.upsStatus = "";
                root.powerDraw = -1;
            }
            collectedOutput = "";
        }
    }

    function parseUpsOutput(output) {
        var lines = output.split('\n');
        var loadPercent = -1;
        var outputVoltage = 0;
        var outputCurrentNominal = 0;
        root.powerDraw = -1;

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            var colonIdx = line.indexOf(":");
            if (colonIdx < 0) continue;

            var key = line.substring(0, colonIdx).trim();
            var value = line.substring(colonIdx + 1).trim();

            if (key === "battery.charge") {
                var charge = parseInt(value, 10);
                if (!isNaN(charge)) batteryCharge = charge;
            } else if (key === "ups.status") {
                upsStatus = value;
            } else if (key === "ups.realpower" && powerDraw < 0) {
                var rp = parseFloat(value);
                if (!isNaN(rp)) powerDraw = rp;
            } else if (key === "input.realpower" && powerDraw < 0) {
                var ip = parseFloat(value);
                if (!isNaN(ip)) powerDraw = ip;
            } else if (key === "ups.load") {
                var load = parseFloat(value);
                if (!isNaN(load)) loadPercent = load;
            } else if (key === "output.voltage") {
                var v = parseFloat(value);
                if (!isNaN(v)) outputVoltage = v;
            } else if (key === "output.current.nominal") {
                var c = parseFloat(value);
                if (!isNaN(c)) outputCurrentNominal = c;
            }
        }

        if (powerDraw < 0 && loadPercent >= 0 && outputVoltage > 0 && outputCurrentNominal > 0) {
            var maxVA = outputVoltage * outputCurrentNominal;
            var maxWatts = maxVA * root.powerFactor;
            powerDraw = (loadPercent / 100) * maxWatts;
            root.powerDrawEstimated = true;
        }
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: root.activeUpsName !== ""

        onTriggered: {
            upsProcess.running = true;
        }
    }
}
