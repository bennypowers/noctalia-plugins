import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

// Hebrew calendar header with date
Rectangle {
    id: root

    property string dafYomi: ""
    property string fontFamily: "Liberation Serif"

    // Hebrew date properties
    property int hebrewDay: 15
    property string hebrewMonth: "טבת"
    property string hebrewWeekday: "א"
    property int hebrewYear: 5786

    function convertToHebrewNumeral(num) {
        var ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"];
        var tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"];
        var hundreds = ["", "ק", "ר", "ש", "ת"];

        if (num < 1)
            return "";

        if (num === 15)
            return "ט״ו";
        if (num === 16)
            return "ט״ז";

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
    function getWeekdayName(abbrev) {
        var names = {
            "א": "ראשון",
            "ב": "שני",
            "ג": "שלישי",
            "ד": "רביעי",
            "ה": "חמישי",
            "ו": "שישי",
            "ש": "שבת"
        };
        return names[abbrev] || abbrev;
    }

    Layout.fillWidth: true
    Layout.minimumHeight: (60 * Style.uiScaleRatio) + (Style.marginM * 2)
    Layout.preferredHeight: (60 * Style.uiScaleRatio) + (Style.marginM * 2)
    color: Color.mPrimary
    implicitHeight: (60 * Style.uiScaleRatio) + (Style.marginM * 2)
    radius: Style.radiusL

    ColumnLayout {
        id: capsuleColumn

        spacing: 0

        anchors {
            bottom: parent.bottom
            bottomMargin: Style.marginM
            left: parent.left
            leftMargin: Style.marginXL
            right: parent.right
            rightMargin: Style.marginXL
            top: parent.top
            topMargin: Style.marginM
        }
        RowLayout {
            Layout.fillWidth: true
            clip: true
            height: 60 * Style.uiScaleRatio
            layoutDirection: Qt.RightToLeft
            spacing: Style.marginS

            // Hebrew day number (large)
            NText {
                Layout.preferredWidth: implicitWidth
                color: Color.mOnPrimary
                font.family: root.fontFamily
                font.weight: Style.fontWeightBold
                pointSize: Style.fontSizeXXXL * 1.5
                text: convertToHebrewNumeral(root.hebrewDay)
            }

            // Month, year, weekday, daf yomi
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.bottomMargin: Style.marginXXS
                Layout.topMargin: -Style.marginXXS
                spacing: -Style.marginXS

                RowLayout {
                    layoutDirection: Qt.RightToLeft
                    spacing: Style.marginS

                    NText {
                        Layout.alignment: Qt.AlignBaseline
                        color: Color.mOnPrimary
                        font.family: root.fontFamily
                        font.weight: Style.fontWeightBold
                        pointSize: Style.fontSizeXL * 1.1
                        text: root.hebrewMonth
                    }
                    NText {
                        Layout.alignment: Qt.AlignBaseline
                        color: Qt.alpha(Color.mOnPrimary, 0.7)
                        font.family: root.fontFamily
                        font.weight: Style.fontWeightBold
                        pointSize: Style.fontSizeM
                        text: convertToHebrewNumeral(root.hebrewYear % 1000)
                    }
                }
                RowLayout {
                    layoutDirection: Qt.RightToLeft
                    spacing: Style.marginS

                    NText {
                        color: Color.mOnPrimary
                        font.family: root.fontFamily
                        pointSize: Style.fontSizeM
                        text: "יום " + getWeekdayName(root.hebrewWeekday)
                    }
                    NText {
                        color: Qt.alpha(Color.mOnPrimary, 0.7)
                        font.family: root.fontFamily
                        pointSize: Style.fontSizeXS
                        text: root.dafYomi
                        visible: root.dafYomi.length > 0
                    }
                }
            }

            // Spacer
            Item {
                Layout.fillWidth: true
            }
        }
    }
}
