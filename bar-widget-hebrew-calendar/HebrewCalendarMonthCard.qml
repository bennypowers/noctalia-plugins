import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

// Hebrew calendar month grid
NBox {
    id: root

    // Hebrew date properties
    property int hebrewDay: 15
    property string hebrewMonth: "טבת"
    property int hebrewYear: 5786
    property int monthLength: 29
    property int firstDayOfWeek: 0  // 0=Sunday, 1=Monday, etc. for the 1st of the month
    property string fontFamily: "Liberation Serif"

    Layout.fillWidth: true
    implicitHeight: calendarContent.implicitHeight + Style.marginM * 2

    ColumnLayout {
        id: calendarContent

        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        // Month/Year header
        RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            layoutDirection: Qt.RightToLeft

            Item {
                Layout.preferredWidth: Style.marginS
            }

            NText {
                color: Color.mOnSurface
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeM
                text: root.hebrewMonth + " " + convertToHebrewNumeral(root.hebrewYear % 1000)
                font.family: root.fontFamily
                horizontalAlignment: Text.AlignRight
            }

            NDivider {
                Layout.fillWidth: true
            }
        }

        // Day names header
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 0
                columns: 7
                rowSpacing: 0
                rows: 1
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: ["א", "ב", "ג", "ד", "ה", "ו", "ש"]

                    Item {
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.fontSizeS * 2

                        NText {
                            anchors.centerIn: parent
                            color: Color.mPrimary
                            font.weight: Style.fontWeightBold
                            horizontalAlignment: Text.AlignHCenter
                            pointSize: Style.fontSizeS
                            text: modelData
                        }
                    }
                }
            }
        }

        // Calendar grid
        GridLayout {
            id: grid

            property var daysModel: {
                const days = [];

                // Get previous month's length
                var prevMonthLength = getPreviousMonthLength(root.hebrewMonth);

                // Add previous month's trailing days
                const daysBefore = root.firstDayOfWeek;
                for (var i = daysBefore - 1; i >= 0; i--) {
                    const day = prevMonthLength - i;
                    days.push({
                        "day": day,
                        "currentMonth": false,
                        "isToday": false
                    });
                }

                // Add current month's days
                for (var day = 1; day <= root.monthLength; day++) {
                    days.push({
                        "day": day,
                        "currentMonth": true,
                        "isToday": day === root.hebrewDay
                    });
                }

                // Add next month's leading days to complete the last week
                const totalSoFar = days.length;
                const daysInLastWeek = totalSoFar % 7;
                const daysAfter = daysInLastWeek === 0 ? 0 : (7 - daysInLastWeek);
                for (var i = 1; i <= daysAfter; i++) {
                    days.push({
                        "day": i,
                        "currentMonth": false,
                        "isToday": false
                    });
                }

                return days;
            }

            Layout.fillWidth: true
            columnSpacing: Style.marginXXS
            columns: 7
            rowSpacing: Style.marginXXS
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: grid.daysModel

                Item {
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.baseWidgetSize * 0.9

                    Rectangle {
                        anchors.centerIn: parent
                        color: modelData.isToday ? Color.mSecondary : "transparent"
                        height: Style.baseWidgetSize * 0.9
                        radius: Style.radiusM
                        width: Style.baseWidgetSize * 0.9

                        Behavior on color {
                            ColorAnimation {
                                duration: Style.animationFast
                            }
                        }

                        NText {
                            anchors.centerIn: parent
                            color: {
                                if (modelData.isToday)
                                    return Color.mOnSecondary;
                                if (modelData.currentMonth)
                                    return Color.mOnSurface;
                                return Color.mOnSurfaceVariant;
                            }
                            opacity: modelData.currentMonth ? 1.0 : 0.4
                            font.weight: modelData.isToday ? Style.fontWeightBold : Style.fontWeightMedium
                            pointSize: Style.fontSizeM
                            text: convertToHebrewNumeral(modelData.day)
                            font.family: root.fontFamily
                        }
                    }
                }
            }
        }
    }

    function convertToHebrewNumeral(num) {
        var ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"];
        var tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"];
        var hundreds = ["", "ק", "ר", "ש", "ת"];

        if (num < 1) return "";

        // Special cases for 15 and 16 to avoid writing God's name (יה and יו)
        if (num === 15) return "ט״ו";  // tet-vav (9+6) instead of yod-hey (10+5)
        if (num === 16) return "ט״ז";  // tet-zayin (9+7) instead of yod-vav (10+6)

        var result = "";

        // Handle hundreds (support up to 999 by using combinations)
        var hundredsValue = Math.floor(num / 100) * 100;
        while (hundredsValue >= 100) {
            if (hundredsValue >= 400) {
                result += "ת";
                hundredsValue -= 400;
            } else if (hundredsValue >= 300) {
                result += "ש";
                hundredsValue -= 300;
            } else if (hundredsValue >= 200) {
                result += "ר";
                hundredsValue -= 200;
            } else if (hundredsValue >= 100) {
                result += "ק";
                hundredsValue -= 100;
            }
        }

        // Handle tens and ones
        var tensDigit = Math.floor((num % 100) / 10);
        var onesDigit = num % 10;

        if (tensDigit > 0 && tensDigit < tens.length) {
            result += tens[tensDigit];
        }

        if (onesDigit > 0 && onesDigit < ones.length) {
            result += ones[onesDigit];
        }

        if (result.length === 1) {
            result += "׳";
        } else if (result.length > 1) {
            result = result.slice(0, -1) + "״" + result.slice(-1);
        }

        return result;
    }

    function getPreviousMonthLength(currentMonth) {
        var monthOrder = [
            "ניסן", "אייר", "סיוון", "תמוז", "אב", "אלול",
            "תשרי", "חשוון", "כסלו", "טבת", "שבט", "אדר"
        ];
        var monthLengths = [
            30, 29, 30, 29, 30, 29,
            30, 29, 30, 29, 30, 29
        ];

        var currentIndex = monthOrder.indexOf(currentMonth);
        if (currentIndex === -1) return 29;

        var prevIndex = (currentIndex - 1 + 12) % 12;
        return monthLengths[prevIndex];
    }
}
