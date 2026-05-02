import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

NScrollView {
    id: root

    property var pluginApi: null

    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AsNeeded
    padding: Style.marginL

    property string valueUpsName: pluginApi?.pluginSettings?.upsName ||
                                  pluginApi?.manifest?.metadata?.defaultSettings?.upsName ||
                                  ""

    property int valueUpdateInterval: pluginApi?.pluginSettings?.updateInterval ||
                                      pluginApi?.manifest?.metadata?.defaultSettings?.updateInterval ||
                                      5000

    property bool valueShowPowerDraw: pluginApi?.pluginSettings?.showPowerDraw !== undefined ? pluginApi.pluginSettings.showPowerDraw :
                                          pluginApi?.manifest?.metadata?.defaultSettings?.showPowerDraw !== undefined ? pluginApi.manifest.metadata.defaultSettings.showPowerDraw :
                                          true

    property bool valueShowBatteryOnlyOnBattery: pluginApi?.pluginSettings?.showBatteryOnlyOnBattery !== undefined ? pluginApi.pluginSettings.showBatteryOnlyOnBattery :
                                                  pluginApi?.manifest?.metadata?.defaultSettings?.showBatteryOnlyOnBattery !== undefined ? pluginApi.manifest.metadata.defaultSettings.showBatteryOnlyOnBattery :
                                                  true

    property string valueBatteryColor: pluginApi?.pluginSettings?.batteryColor ||
                                       pluginApi?.manifest?.metadata?.defaultSettings?.batteryColor ||
                                       "error"

    property real valuePowerFactor: pluginApi?.pluginSettings?.powerFactor ||
                                    pluginApi?.manifest?.metadata?.defaultSettings?.powerFactor ||
                                    0.6

    property var availableUpsNames: []

    Component.onCompleted: {
        upsListProcess.running = true;
    }

    ColumnLayout {
        width: parent.width
        spacing: Style.marginM

        NHeader {
            label: "UPS Configuration"
            description: "Select which UPS to monitor"
        }

        NComboBox {
            Layout.fillWidth: true
            label: "UPS Name"
            description: "Select the UPS to monitor from NUT"
            model: {
                var items = [];
                for (var i = 0; i < root.availableUpsNames.length; i++) {
                    items.push({name: root.availableUpsNames[i], key: root.availableUpsNames[i]});
                }
                if (items.length === 0) {
                    items.push({name: "(No UPS found)", key: ""});
                }
                return items;
            }
            currentKey: root.valueUpsName
            onSelected: function(key) {
                root.valueUpsName = key;
            }
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        NHeader {
            label: "Update Settings"
            description: "How often to query the UPS for new data"
        }

        NSpinBox {
            Layout.fillWidth: true
            label: "Update Interval"
            description: "Polling interval in milliseconds"
            minimum: 1000
            maximum: 60000
            stepSize: 1000
            value: root.valueUpdateInterval
            onValueChanged: function(value) {
                root.valueUpdateInterval = value;
            }
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        NHeader {
            label: "Display Options"
            description: "Customize what the bar widget shows"
        }

        NToggle {
            Layout.fillWidth: true
            label: "Show Power Draw"
            description: "Display current power draw in watts"
            checked: root.valueShowPowerDraw
            onToggled: function(checked) {
                root.valueShowPowerDraw = checked;
            }
        }

        NToggle {
            Layout.fillWidth: true
            label: "Show Battery % Only on Battery"
            description: "Hide percentage when UPS is on mains power"
            checked: root.valueShowBatteryOnlyOnBattery
            onToggled: function(checked) {
                root.valueShowBatteryOnlyOnBattery = checked;
            }
        }

        NComboBox {
            Layout.fillWidth: true
            label: "On-Battery Color"
            description: "Color for battery icon when UPS is on battery power"
            model: [
                {name: "Auto (Default)", key: "auto"},
                {name: "Tertiary (Blue)", key: "tertiary"},
                {name: "Warning (Amber)", key: "warning"},
                {name: "Error (Red)", key: "error"},
                {name: "Primary", key: "primary"},
                {name: "Surface (Neutral)", key: "onsurface"}
            ]
            currentKey: root.valueBatteryColor
            onSelected: function(key) {
                root.valueBatteryColor = key;
            }
        }

        NValueSlider {
            Layout.fillWidth: true
            label: "Power Factor"
            description: "Ratio of real power to apparent power (typically 0.6-0.9)"
            from: 0.1
            to: 1.0
            stepSize: 0.01
            value: root.valuePowerFactor
            onMoved: function(value) {
                root.valuePowerFactor = value;
            }
            text: Math.round(root.valuePowerFactor * 100) / 100
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        NButton {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginM
            text: "Save Settings"
            onClicked: saveSettings()
        }
    }

    function saveSettings() {
        if (!pluginApi) {
            console.error("NUT Status: Cannot save settings - pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.upsName = root.valueUpsName;
        pluginApi.pluginSettings.updateInterval = root.valueUpdateInterval;
        pluginApi.pluginSettings.showPowerDraw = root.valueShowPowerDraw;
        pluginApi.pluginSettings.showBatteryOnlyOnBattery = root.valueShowBatteryOnlyOnBattery;
        pluginApi.pluginSettings.batteryColor = root.valueBatteryColor;
        pluginApi.pluginSettings.powerFactor = root.valuePowerFactor;
        pluginApi.saveSettings();
    }

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
                var names = [];
                var lines = collectedOutput.trim().split('\n');
                for (var i = 0; i < lines.length; i++) {
                    var name = lines[i].trim();
                    if (name) {
                        names.push(name);
                    }
                }
                root.availableUpsNames = names;
                if (!root.valueUpsName && names.length > 0) {
                    root.valueUpsName = names[0];
                }
            }
            collectedOutput = "";
        }
    }
}
