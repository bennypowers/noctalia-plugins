import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NScrollView {
    id: root

    property var pluginApi: null

    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AsNeeded
    padding: Style.marginL

    property string valueDisplayMode: pluginApi?.pluginSettings?.displayMode ||
                                      pluginApi?.manifest?.metadata?.defaultSettings?.displayMode ||
                                      "full"

    ColumnLayout {
        width: parent.width
        spacing: Style.marginM

        NHeader {
            label: "Display Mode"
            description: "Choose how background apps are shown in the bar"
        }

        NComboBox {
            Layout.fillWidth: true
            label: "Mode"
            description: "Full shows all app icons; Menu shows a single button"
            model: [
                {name: "Full", key: "full"},
                {name: "Menu Button", key: "menu"}
            ]
            currentKey: root.valueDisplayMode
            onSelected: function (key) {
                root.valueDisplayMode = key;
            }
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
            console.error("Background Apps: Cannot save settings - pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.displayMode = root.valueDisplayMode;
        pluginApi.saveSettings();
    }
}
