import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property var screen: null

    // Access main component state via pluginApi
    property var main: pluginApi?.mainInstance ?? null

    // SmartPanel positioning - center on screen, don't attach to bar
    readonly property bool allowAttach: false
    readonly property bool panelAnchorHorizontalCenter: true
    readonly property bool panelAnchorVerticalCenter: true

    // SmartPanel sizing - width fixed, height dynamic based on content
    property real contentPreferredWidth: Math.round(420 * Style.uiScaleRatio)
    property real contentPreferredHeight: contentColumn.implicitHeight + Style.marginL * 2

    // Geometry placeholder for SmartPanel background rendering
    readonly property var geometryPlaceholder: panelContainer

    // Keyboard handler for escape to cancel
    function onEscapePressed() {
        cancel()
    }

    function submit() {
        if (!main || !passwordInput.text) return
        main.submitResponse(passwordInput.text)
        passwordInput.text = ""
    }

    function cancel() {
        if (!main) return
        main.cancelAuthorization()
        passwordInput.text = ""
    }

    // Focus password input when panel opens
    Component.onCompleted: {
        console.log("[polkit-agent] Panel loaded")
        passwordInput.forceActiveFocus()
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: Color.transparent

        ColumnLayout {
            id: contentColumn
            width: parent.width - Style.marginL * 2
            x: Style.marginL
            y: Style.marginL
            spacing: Style.marginM

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                // Lock icon
                Rectangle {
                    Layout.preferredWidth: Math.round(48 * Style.uiScaleRatio)
                    Layout.preferredHeight: Math.round(48 * Style.uiScaleRatio)
                    radius: Style.radiusM
                    color: Color.mPrimary

                    NText {
                        anchors.centerIn: parent
                        text: "\uf023"
                        font.pixelSize: Style.fontSizeL
                        color: Color.mOnPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    NText {
                        text: "Authentication Required"
                        font.pixelSize: Style.fontSizeL
                        font.weight: Font.Bold
                        color: Color.mOnSurface
                    }

                    NText {
                        text: main?.currentMessage || "An application is requesting access"
                        font.pixelSize: Style.fontSizeM
                        color: Color.mOnSurfaceVariant
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Action ID
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: actionIdText.implicitHeight + Style.marginS * 2
                color: Color.mSurfaceVariant
                radius: Style.radiusS

                NText {
                    id: actionIdText
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    text: main?.currentActionId ?? ""
                    font.pixelSize: Style.fontSizeXS
                    font.family: "monospace"
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideMiddle
                }
            }

            // Error message
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: errorText.implicitHeight + Style.marginS * 2
                color: Color.mError
                radius: Style.radiusS
                visible: (main?.errorMessage?.length ?? 0) > 0
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                NText {
                    id: errorText
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    text: main?.errorMessage ?? ""
                    font.pixelSize: Style.fontSizeM
                    color: Color.mOnError
                }
            }

            // Password input
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                    text: main?.currentRequest || "Password:"
                    font.pixelSize: Style.fontSizeM
                    color: Color.mOnSurface
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(44 * Style.uiScaleRatio)
                    color: Color.mSurfaceVariant
                    radius: Style.radiusS
                    border.color: passwordInput.activeFocus ? Color.mPrimary : Color.mOutline
                    border.width: passwordInput.activeFocus ? 2 : 1

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.margins: Style.marginS
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Style.fontSizeM
                        color: Color.mOnSurface
                        echoMode: (main?.currentEcho ?? false) ? TextInput.Normal : TextInput.Password
                        selectByMouse: true

                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: root.cancel()
                    }
                }
            }

            // Connection status warning
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: connectionText.implicitHeight + Style.marginS * 2
                color: Color.mTertiary
                radius: Style.radiusS
                visible: !(main?.isConnected ?? true)
                opacity: visible ? 1 : 0

                NText {
                    id: connectionText
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    text: "Not connected to polkit agent"
                    font.pixelSize: Style.fontSizeM
                    color: Color.mOnTertiary
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Style.marginS
                spacing: Style.marginM

                Item { Layout.fillWidth: true }

                NButton {
                    text: "Cancel"
                    onClicked: root.cancel()
                }

                NButton {
                    text: "Authenticate"
                    enabled: passwordInput.text.length > 0 && (main?.isConnected ?? false)
                    onClicked: root.submit()
                }
            }
        }
    }
}
