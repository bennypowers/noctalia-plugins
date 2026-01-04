import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Shabbat times and parsha card
NBox {
    id: root

    property string parsha: ""
    property string candleLighting: ""
    property string havdalah: ""
    property string fontFamily: "Liberation Serif"

    Layout.fillWidth: true
    implicitHeight: shabbatContent.implicitHeight + Style.marginXL * 2
    visible: parsha.length > 0 || candleLighting.length > 0

    ColumnLayout {
        id: shabbatContent
        anchors.fill: parent
        anchors.margins: Style.marginXL
        spacing: Style.marginL

        // Header with candle graphic
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginL
            layoutDirection: Qt.RightToLeft

            // Two candles using Unicode
            RowLayout {
                spacing: Style.marginXS
                layoutDirection: Qt.LeftToRight

                NText {
                    text: "🕯️"
                    pointSize: Style.fontSizeXXXL * 1.5
                }

                NText {
                    text: "🕯️"
                    pointSize: Style.fontSizeXXXL * 1.5
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXXS

                NText {
                    text: "שבת שלום"
                    pointSize: Style.fontSizeXL
                    font.weight: Style.fontWeightBold
                    font.family: root.fontFamily
                    color: Color.mPrimary
                }

                NText {
                    text: root.parsha
                    pointSize: Style.fontSizeM
                    font.family: root.fontFamily
                    color: Color.mOnSurface
                    visible: root.parsha.length > 0
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }

        NDivider {
            Layout.fillWidth: true
            visible: root.candleLighting.length > 0 || root.havdalah.length > 0
        }

        // Grid view for times
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Style.marginM
            columnSpacing: Style.marginL
            layoutDirection: Qt.RightToLeft

            // Candle lighting
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXXS
                visible: root.candleLighting.length > 0

                NText {
                    text: "הדלקת נרות"
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                    font.family: root.fontFamily
                    horizontalAlignment: Text.AlignRight
                }

                NText {
                    text: root.candleLighting
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeL
                    color: Color.mPrimary
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Havdalah
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.marginXXS
                visible: root.havdalah.length > 0

                NText {
                    text: "הבדלה"
                    color: Color.mOnSurfaceVariant
                    pointSize: Style.fontSizeS
                    font.family: root.fontFamily
                    horizontalAlignment: Text.AlignRight
                }

                NText {
                    text: root.havdalah
                    font.weight: Style.fontWeightBold
                    pointSize: Style.fontSizeL
                    color: Color.mPrimary
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
