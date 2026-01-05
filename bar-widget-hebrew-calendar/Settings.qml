import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

NScrollView {
    id: root

    property var pluginApi: null

    horizontalPolicy: ScrollBar.AlwaysOff
    verticalPolicy: ScrollBar.AsNeeded
    padding: Style.marginL

    // Local state for settings
    property string valueTemplate: pluginApi?.pluginSettings?.template ||
                                   pluginApi?.manifest?.metadata?.defaultSettings?.template ||
                                   "{day} {month}"
    property string valueCity: pluginApi?.pluginSettings?.city ||
                              pluginApi?.manifest?.metadata?.defaultSettings?.city ||
                              "Jerusalem"
    property bool valueIsraeli: pluginApi?.pluginSettings?.israeli !== undefined ?
                               pluginApi.pluginSettings.israeli :
                               (pluginApi?.manifest?.metadata?.defaultSettings?.israeli !== undefined ?
                                pluginApi.manifest.metadata.defaultSettings.israeli : true)
    property string valueLanguage: pluginApi?.pluginSettings?.language ||
                                  pluginApi?.manifest?.metadata?.defaultSettings?.language ||
                                  "he-x-NoNikud"
    property string valueFontFamily: pluginApi?.pluginSettings?.fontFamily ||
                                    pluginApi?.manifest?.metadata?.defaultSettings?.fontFamily ||
                                    "Liberation Serif"
    property ListModel availableFonts: ListModel {}

    Component.onCompleted: {
        fontDetector.running = true;
    }

    // Process to detect available Hebrew fonts
    Process {
        id: fontDetector

        command: ["fc-list", ":lang=he", "--format", "%{family[0]}\\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                var fontSet = {};
                var lines = this.text.split('\n');

                // Deduplicate fonts
                for (var i = 0; i < lines.length; i++) {
                    var fontName = lines[i].trim();
                    if (fontName && !fontSet[fontName]) {
                        fontSet[fontName] = true;
                    }
                }

                // Add common fallbacks
                fontSet["Sans Serif"] = true;
                fontSet["Serif"] = true;
                fontSet["Monospace"] = true;

                // Sort and populate model
                var sortedFonts = Object.keys(fontSet).sort(function (a, b) {
                    return a.localeCompare(b);
                });

                root.availableFonts.clear();
                for (var j = 0; j < sortedFonts.length; j++) {
                    var name = sortedFonts[j];
                    root.availableFonts.append({
                        "key": name,
                        "name": name
                    });
                }
            }
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.error("Hebrew Calendar: fc-list failed with exit code", exitCode);
            }
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: Style.marginM

        // Font Settings
        NHeader {
            label: "Font"
            description: "Font family for displaying Hebrew text"
        }

        NSearchableComboBox {
            id: fontComboBox
            Layout.fillWidth: true
            label: "Font Family"
            description: "Choose a font that supports Hebrew characters"
            model: root.availableFonts
            currentKey: root.valueFontFamily
            placeholder: "Liberation Serif"
            searchPlaceholder: "Search fonts..."
            popupHeight: 300
            minimumWidth: 300
            onSelected: function (key) {
                root.valueFontFamily = key;
            }
        }

        // Font preview
        NText {
            Layout.topMargin: -Style.marginS
            text: "Preview: ד׳ טבת ה׳תשפ״ה"
            color: Color.mOnSurfaceVariant
            font.family: root.valueFontFamily.length > 0 ? root.valueFontFamily : "Liberation Serif"
            pointSize: Style.fontSizeL
            LayoutMirroring.enabled: true
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        // Location Settings
        NHeader {
            label: "Location"
            description: "City for calculating holidays and prayer times"
        }

        NTextInput {
            id: cityInput
            Layout.fillWidth: true
            label: "City"
            description: "Enter your city name (e.g., Jerusalem, Tel Aviv, New York)"
            placeholderText: "Jerusalem"
            text: root.valueCity
            onTextChanged: {
                root.valueCity = text;
            }
        }

        NComboBox {
            Layout.fillWidth: true
            label: "Common Cities"
            description: "Or select from common cities"
            model: [
                {name: "Jerusalem", key: "Jerusalem"},
                {name: "Tel Aviv", key: "Tel Aviv"},
                {name: "Haifa", key: "Haifa"},
                {name: "Beer Sheva", key: "Beer Sheva"},
                {name: "New York", key: "New York"},
                {name: "London", key: "London"},
                {name: "Paris", key: "Paris"},
                {name: "Los Angeles", key: "Los Angeles"}
            ]
            currentKey: root.valueCity
            onSelected: function (key) {
                root.valueCity = key;
                cityInput.text = key;
            }
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        // Holiday Schedule
        NHeader {
            label: "Holiday Schedule"
            description: "Select the appropriate holiday schedule for your location"
        }

        NComboBox {
            Layout.fillWidth: true
            label: "Holiday Calendar"
            description: "Use Israeli or Diaspora holiday schedule"
            model: [
                {name: "Israeli", key: "israeli"},
                {name: "Diaspora", key: "diaspora"}
            ]
            currentKey: root.valueIsraeli ? "israeli" : "diaspora"
            onSelected: function (key) {
                root.valueIsraeli = (key === "israeli");
            }
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        // Language Settings
        NHeader {
            label: "Language"
            description: "Display language for Hebrew date"
        }

        NComboBox {
            Layout.fillWidth: true
            label: "Display Language"
            description: "Select how Hebrew dates should be displayed"
            model: [
                {name: "Hebrew (no vowels) - ט״ו טבת תשפ״ו", key: "he-x-NoNikud"},
                {name: "Hebrew (with vowels) - ט״ו טֵבֵת תשפ״ו", key: "he"},
                {name: "English - 15 Tevet 5786", key: "en"},
                {name: "Ashkenazi - 15 Teves 5786", key: "ashkenazi"}
            ]
            currentKey: root.valueLanguage
            popupHeight: 220
            onSelected: function (key) {
                root.valueLanguage = key;
            }
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        // Template Settings
        NHeader {
            label: "Date Format"
            description: "Customize how the Hebrew date is displayed"
        }

        NTextInput {
            id: templateInput
            Layout.fillWidth: true
            label: "Custom Template"
            description: "Use placeholders: {day}, {month}, {year}, {weekday}"
            placeholderText: "{day} {month}"
            text: root.valueTemplate
            onTextChanged: {
                root.valueTemplate = text;
            }
        }

        // Example output
        NText {
            Layout.topMargin: -Style.marginS
            text: "Example: " + formatExample()
            color: Color.mOnSurfaceVariant
            font.family: root.valueFontFamily
            pointSize: Style.fontSizeS
            visible: root.valueTemplate.length > 0
            LayoutMirroring.enabled: true
        }

        NComboBox {
            Layout.fillWidth: true
            label: "Preset Templates"
            description: "Choose a preset format"
            model: [
                {name: "Day and Month", key: "{day} {month}"},
                {name: "Day, Month, Year", key: "{day} {month} {year}"},
                {name: "Weekday and Date", key: "{weekday}, {day} {month}"},
                {name: "Full Date", key: "{weekday}, {day} {month} {year}"},
                {name: "Month and Day", key: "{month} {day}"},
                {name: "Day Only", key: "{day}"}
            ]
            currentKey: root.valueTemplate
            popupHeight: 280
            onSelected: function (key) {
                root.valueTemplate = key;
                templateInput.text = key;
            }
        }

        NDivider {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginS
            Layout.bottomMargin: Style.marginS
        }

        // Save Button
        NButton {
            Layout.fillWidth: true
            Layout.topMargin: Style.marginM
            text: "Save Settings"
            onClicked: saveSettings()
        }
    }

    function formatExample() {
        // Generate example with sample Hebrew date
        var example = root.valueTemplate;
        example = example.replace(/{day}/g, "ד׳");
        example = example.replace(/{month}/g, "טבת");
        example = example.replace(/{year}/g, "ה׳תשפ״ה");
        example = example.replace(/{weekday}/g, "ראשון");
        return example;
    }

    function saveSettings() {
        if (!pluginApi) {
            console.error("Hebrew Calendar: Cannot save settings - pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.template = root.valueTemplate;
        pluginApi.pluginSettings.city = root.valueCity;
        pluginApi.pluginSettings.israeli = root.valueIsraeli;
        pluginApi.pluginSettings.language = root.valueLanguage;
        pluginApi.pluginSettings.fontFamily = root.valueFontFamily;
        pluginApi.saveSettings();
    }
}
