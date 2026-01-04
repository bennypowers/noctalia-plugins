import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    required property var pluginApi

    spacing: Style.marginL

    // Local state for settings
    property string valueLayout: pluginApi?.pluginSettings?.layout ||
                                 pluginApi?.manifest?.metadata?.defaultSettings?.layout ||
                                 "vertical"
    property string valueVerticalDirection: pluginApi?.pluginSettings?.verticalDirection ||
                                           pluginApi?.manifest?.metadata?.defaultSettings?.verticalDirection ||
                                           "ltr"
    property string valueHorizontalDirection: pluginApi?.pluginSettings?.horizontalDirection ||
                                             pluginApi?.manifest?.metadata?.defaultSettings?.horizontalDirection ||
                                             "ttb"

    // Layout orientation setting
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
            text: "Layout Orientation"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Choose how the CPU bars are arranged"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        RowLayout {
            spacing: Style.marginM

            Rectangle {
                implicitWidth: 100
                implicitHeight: 32
                color: root.valueLayout === "vertical" ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Vertical"
                    color: root.valueLayout === "vertical" ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueLayout = "vertical";
                        saveSettings();
                    }
                }
            }

            Rectangle {
                implicitWidth: 100
                implicitHeight: 32
                color: root.valueLayout === "horizontal" ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Horizontal"
                    color: root.valueLayout === "horizontal" ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueLayout = "horizontal";
                        saveSettings();
                    }
                }
            }
        }
    }

    // Vertical direction setting (only show when vertical)
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        visible: root.valueLayout === "vertical"

        NText {
            text: "Vertical Bar Direction"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Direction for vertical bars to grow"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        RowLayout {
            spacing: Style.marginM

            Rectangle {
                implicitWidth: 120
                implicitHeight: 32
                color: root.valueVerticalDirection === "ltr" ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Left to Right"
                    color: root.valueVerticalDirection === "ltr" ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueVerticalDirection = "ltr";
                        saveSettings();
                    }
                }
            }

            Rectangle {
                implicitWidth: 120
                implicitHeight: 32
                color: root.valueVerticalDirection === "rtl" ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Right to Left"
                    color: root.valueVerticalDirection === "rtl" ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueVerticalDirection = "rtl";
                        saveSettings();
                    }
                }
            }
        }
    }

    // Horizontal direction setting (only show when horizontal)
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        visible: root.valueLayout === "horizontal"

        NText {
            text: "Horizontal Bar Direction"
            font.bold: true
            pointSize: Style.fontSizeM
        }

        NText {
            text: "Direction for horizontal bars to grow"
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
        }

        RowLayout {
            spacing: Style.marginM

            Rectangle {
                implicitWidth: 120
                implicitHeight: 32
                color: root.valueHorizontalDirection === "ttb" ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Top to Bottom"
                    color: root.valueHorizontalDirection === "ttb" ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueHorizontalDirection = "ttb";
                        saveSettings();
                    }
                }
            }

            Rectangle {
                implicitWidth: 120
                implicitHeight: 32
                color: root.valueHorizontalDirection === "btt" ? Color.mPrimary : Color.mSurface
                border.color: Color.mOutline
                border.width: 1
                radius: Style.radiusM

                NText {
                    anchors.centerIn: parent
                    text: "Bottom to Top"
                    color: root.valueHorizontalDirection === "btt" ? Color.mOnPrimary : Color.mOnSurface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.valueHorizontalDirection = "btt";
                        saveSettings();
                    }
                }
            }
        }
    }

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("threadbars", "Cannot save settings: pluginApi is null");
            return;
        }

        Logger.i("threadbars", "Saving settings - layout: " + root.valueLayout +
                              ", verticalDirection: " + root.valueVerticalDirection +
                              ", horizontalDirection: " + root.valueHorizontalDirection);

        pluginApi.pluginSettings.layout = root.valueLayout;
        pluginApi.pluginSettings.verticalDirection = root.valueVerticalDirection;
        pluginApi.pluginSettings.horizontalDirection = root.valueHorizontalDirection;
        pluginApi.saveSettings();
    }
}
