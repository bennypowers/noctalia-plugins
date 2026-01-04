import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    spacing: Style.marginL

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
    property var availableFonts: ["Liberation Serif", "Liberation Sans", "Sans Serif", "Serif"]

    Component.onCompleted: {
        fontDetector.running = true;
    }

    // Process to detect available Hebrew fonts
    Process {
        id: fontDetector

        command: ["bash", "-c", "fc-list :lang=he family | sort -u"]

        stdout: SplitParser {
            onRead: function (data) {
                if (data && data.trim()) {
                    var fonts = data.trim().split("\n");
                    // Add common fallbacks
                    fonts.push("Sans Serif");
                    fonts.push("Serif");
                    fonts.push("Monospace");
                    root.availableFonts = fonts;
                    console.log("Hebrew Calendar Settings: Detected fonts:", fonts);
                }
            }
        }
    }

    // Font family setting
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Font"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Font family for displaying Hebrew text"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        NTextInput {
            id: fontInput

            Layout.fillWidth: true
            label: "Font Family"
            description: "e.g., Liberation Serif, Noto Sans Hebrew, David, Arial"
            placeholderText: "Liberation Serif"
            text: root.valueFontFamily

            onTextChanged: {
                root.valueFontFamily = text;
            }
        }

        // Font preview
        NText {
            text: "Preview: " + (root.valueFontFamily.length > 0 ? "ד׳ טבת ה׳תשפ״ה" : "")
            color: Color.mOnSurface
            font.family: root.valueFontFamily.length > 0 ? root.valueFontFamily : "Liberation Serif"
            pointSize: Style.fontSizeM
            visible: root.valueFontFamily.length > 0
            LayoutMirroring.enabled: true
        }

        // Available fonts (detected at runtime)
        Flow {
            Layout.fillWidth: true
            spacing: Style.marginXS

            Repeater {
                model: root.availableFonts

                delegate: Rectangle {
                    required property string modelData

                    implicitWidth: fontButtonText.implicitWidth + Style.marginM * 2
                    implicitHeight: 28
                    color: Color.mSurface
                    border.color: Color.mOutline
                    border.width: 1
                    radius: Style.radiusS

                    NText {
                        id: fontButtonText
                        anchors.centerIn: parent
                        text: modelData
                        color: Color.mOnSurface
                        pointSize: Style.fontSizeXS
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.valueFontFamily = modelData;
                            fontInput.text = modelData;
                        }
                    }
                }
            }
        }
    }

    // City setting
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Location"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "City for calculating holidays and times"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        NTextInput {
            id: cityInput

            Layout.fillWidth: true
            label: "City"
            description: "e.g., Jerusalem, Tel Aviv, New York, London"
            placeholderText: "Jerusalem"
            text: root.valueCity

            onTextChanged: {
                root.valueCity = text;
            }
        }

        // Common cities shortcuts
        Flow {
            Layout.fillWidth: true
            spacing: Style.marginXS

            Repeater {
                model: ["Jerusalem", "Tel Aviv", "Haifa", "Beer Sheva", "New York", "London", "Paris", "Los Angeles"]

                delegate: Rectangle {
                    required property string modelData

                    implicitWidth: cityButtonText.implicitWidth + Style.marginM * 2
                    implicitHeight: 28
                    color: Color.mSurface
                    border.color: Color.mOutline
                    border.width: 1
                    radius: Style.radiusS

                    NText {
                        id: cityButtonText
                        anchors.centerIn: parent
                        text: modelData
                        color: Color.mOnSurface
                        pointSize: Style.fontSizeXS
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.valueCity = modelData;
                            cityInput.text = modelData;
                        }
                    }
                }
            }
        }
    }

    // Israeli holidays toggle
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Holiday Schedule"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Use Israeli or Diaspora holiday schedule"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        RowLayout {
            spacing: Style.marginM

            Rectangle {
                implicitWidth: 100
                implicitHeight: 32
                color: root.valueIsraeli ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Israeli"
                    color: root.valueIsraeli ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueIsraeli = true;
                    }
                }
            }

            Rectangle {
                implicitWidth: 100
                implicitHeight: 32
                color: !root.valueIsraeli ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Diaspora"
                    color: !root.valueIsraeli ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueIsraeli = false;
                    }
                }
            }
        }
    }

    // Language setting
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Language"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Display language for Hebrew date"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        ColumnLayout {
            spacing: Style.marginXS

            Repeater {
                model: [
                    {value: "he-x-NoNikud", label: "Hebrew (no vowels)", example: "ראשון, ט״ו טבת תשפ״ו"},
                    {value: "he", label: "Hebrew (with vowels)", example: "ראשון, ט״ו טֵבֵת תשפ״ו"},
                    {value: "en", label: "English", example: "ראשון, 15 Tevet 5786"},
                    {value: "ashkenazi", label: "Ashkenazi", example: "ראשון, 15 Teves 5786"}
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 48
                    color: root.valueLanguage === modelData.value ? Color.mSurfaceVariant : Color.mSurface
                    border.color: root.valueLanguage === modelData.value ? Color.mPrimary : Color.mOutline
                    border.width: root.valueLanguage === modelData.value ? 2 : 1
                    radius: Style.radiusM

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Style.marginS
                        spacing: 2

                        NText {
                            text: modelData.label
                            color: Color.mOnSurface
                            font.bold: root.valueLanguage === modelData.value
                            pointSize: Style.fontSizeS
                        }

                        NText {
                            text: modelData.example
                            color: Color.mOnSurfaceVariant
                            font.family: "Deja Vu Serif"
                            pointSize: Style.fontSizeXS
                            LayoutMirroring.enabled: modelData.value.startsWith("he")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.valueLanguage = modelData.value;
                        }
                    }
                }
            }
        }
    }

    // Template setting
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Date Format Template"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Customize how the Hebrew date is displayed"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        NTextInput {
            id: templateInput

            Layout.fillWidth: true
            label: "Template"
            description: "Use placeholders: {day}, {month}, {year}, {weekday}"
            placeholderText: "{day} {month}"
            text: root.valueTemplate

            onTextChanged: {
                root.valueTemplate = text;
            }
        }

        // Example output
        NText {
            text: "Example: " + formatExample()
            color: Color.mOnSurfaceVariant
            font.family: "Deja Vu Serif"
            pointSize: Style.fontSizeS
            visible: root.valueTemplate.length > 0

            LayoutMirroring.enabled: true
        }
    }

    // Preset templates
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Preset Templates"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Click to use a preset format"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        ColumnLayout {
            spacing: Style.marginXS

            Repeater {
                model: [
                    {label: "Day and Month", template: "{day} {month}"},
                    {label: "Day, Month, Year", template: "{day} {month} {year}"},
                    {label: "Weekday and Date", template: "{weekday}, {day} {month}"},
                    {label: "Full Date", template: "{weekday}, {day} {month} {year}"},
                    {label: "Month and Day", template: "{month} {day}"},
                    {label: "Day Only", template: "{day}"}
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 36
                    color: Color.mSurface
                    border.color: Color.mOutline
                    border.width: 1
                    radius: Style.radiusM

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Style.marginS
                        spacing: Style.marginM

                        NText {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Color.mOnSurface
                            pointSize: Style.fontSizeS
                        }

                        NText {
                            text: modelData.template
                            color: Color.mOnSurfaceVariant
                            font.family: "monospace"
                            pointSize: Style.fontSizeXS
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.valueTemplate = modelData.template;
                            templateInput.text = modelData.template;
                            saveSettings();
                        }
                    }
                }
            }
        }
    }

    // Save button
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 40
        color: Color.mPrimary
        radius: Style.radiusM

        NText {
            anchors.centerIn: parent
            text: "Save"
            color: Color.mOnPrimary
            font.bold: true
            pointSize: Style.fontSizeM
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
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
            Logger.e("hebrew-calendar", "Cannot save settings: pluginApi is null");
            return;
        }

        Logger.i("hebrew-calendar", "Saving settings - city: " + root.valueCity +
                                   ", israeli: " + root.valueIsraeli +
                                   ", language: " + root.valueLanguage +
                                   ", template: " + root.valueTemplate);

        pluginApi.pluginSettings.template = root.valueTemplate;
        pluginApi.pluginSettings.city = root.valueCity;
        pluginApi.pluginSettings.israeli = root.valueIsraeli;
        pluginApi.pluginSettings.language = root.valueLanguage;
        pluginApi.pluginSettings.fontFamily = root.valueFontFamily;
        pluginApi.saveSettings();
    }
}
