import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Zmanim (prayer times) card
NBox {
    id: root

    property var zmanimList: []
    property string fontFamily: "Liberation Serif"

    Layout.fillWidth: true
    implicitHeight: Math.min(zmanimContent.implicitHeight + Style.marginM * 2, 200 * Style.uiScaleRatio)

    Component.onCompleted: {
        scrollTimer.start();
    }

    onZmanimListChanged: {
        scrollTimer.restart();
    }

    Timer {
        id: scrollTimer
        interval: 250
        repeat: false
        onTriggered: scrollToNextZman()
    }

    function scrollToNextZman() {
        var nextIndex = -1;
        for (var i = 0; i < zmanimList.length; i++) {
            if (zmanimList[i].status === "next") {
                nextIndex = i;
                break;
            }
        }

        if (nextIndex > 0 && zmanimRepeater.count > 0) {
            var item = zmanimRepeater.itemAt(nextIndex);
            if (item) {
                var targetY = item.y - 40 * Style.uiScaleRatio;
                scrollView.contentItem.contentY = Math.max(0, targetY);
            }
        }
    }

    NScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: Style.marginM
        contentWidth: availableWidth

        ColumnLayout {
            id: zmanimContent
            width: parent.width
            spacing: Style.marginXS

            Repeater {
                id: zmanimRepeater
                model: root.zmanimList

                Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: zmanimRow.implicitHeight + Style.marginXS * 2
                    color: index % 2 === 0 ? Color.mSurface : Color.mSurfaceVariant
                    radius: Style.radiusS

                    RowLayout {
                        id: zmanimRow
                        anchors.fill: parent
                        anchors.margins: Style.marginXS
                        spacing: Style.marginXS
                        layoutDirection: Qt.RightToLeft

                        NText {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: modelData.status === "passed" ? Color.mOnSurfaceVariant : Color.mOnSurface
                            opacity: modelData.status === "passed" ? 0.5 : 1.0
                            pointSize: Style.fontSizeS
                            font.family: root.fontFamily
                            font.weight: modelData.status === "next" ? Style.fontWeightBold : Style.fontWeightRegular
                            horizontalAlignment: Text.AlignRight
                        }

                        NText {
                            text: modelData.time
                            color: modelData.status === "passed" ? Color.mOnSurfaceVariant : Color.mOnSurface
                            opacity: modelData.status === "passed" ? 0.5 : 1.0
                            font.weight: modelData.status === "next" ? Style.fontWeightBold : Style.fontWeightMedium
                            pointSize: Style.fontSizeS
                        }
                    }
                }
            }
        }
    }
}
