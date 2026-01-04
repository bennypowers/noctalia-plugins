import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Rectangle {
    id: root

    // Layout helpers
    readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"
    property string barPosition: ""
    readonly property string city: pluginApi?.pluginSettings?.city || pluginApi?.manifest?.metadata?.defaultSettings?.city || "Jerusalem"

    // Settings
    readonly property string displayTemplate: pluginApi?.pluginSettings?.template || pluginApi?.manifest?.metadata?.defaultSettings?.template || "{day} {month}"
    readonly property string fontFamily: pluginApi?.pluginSettings?.fontFamily || pluginApi?.manifest?.metadata?.defaultSettings?.fontFamily || "Liberation Serif"

    // Hebrew date components
    property string hebrewDay: ""
    property string hebrewMonth: ""
    property string hebrewWeekday: ""
    property string hebrewYear: ""
    property string holidayName: ""
    property bool isHoliday: false
    readonly property bool israeli: pluginApi?.pluginSettings?.israeli !== undefined ? pluginApi.pluginSettings.israeli : (pluginApi?.manifest?.metadata?.defaultSettings?.israeli !== undefined ? pluginApi.manifest.metadata.defaultSettings.israeli : true)
    readonly property string language: pluginApi?.pluginSettings?.language || pluginApi?.manifest?.metadata?.defaultSettings?.language || "he-x-NoNikud"

    // Bar widget properties (injected by Noctalia)
    property var pluginApi: null
    property var screen: null
    property string section: ""
    property string widgetId: ""

    function buildHebcalCommand() {
        var cmd = "hebcal";

        // Add language flag
        cmd += " --lang " + language;

        // Add city if specified
        if (city && city.length > 0) {
            cmd += " --city '" + city + "'";
        }

        // Add Israeli holidays flag
        if (israeli) {
            cmd += " -i";
        }

        // Add weekday flag
        cmd += " -w";

        // Today only
        cmd += " -T";

        // Get first line only
        cmd += " | head -1";

        console.log("Hebrew Calendar: Running command:", cmd);
        return cmd;
    }
    function convertMonthToHebrew(englishMonth) {
        var monthMap = {
            "Nisan": "ניסן",
            "Iyyar": "אייר",
            "Sivan": "סיוון",
            "Tammuz": "תמוז",
            "Av": "אב",
            "Elul": "אלול",
            "Tishrei": "תשרי",
            "Cheshvan": "חשוון",
            "Kislev": "כסלו",
            "Tevet": "טבת",
            "Shvat": "שבט",
            "Adar": "אדר",
            "Adar1": "אדר א׳",
            "Adar2": "אדר ב׳"
        };
        return monthMap[englishMonth] || englishMonth;
    }
    function convertToHebrewNumeral(num) {
        var ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"];
        var tens = ["", "י", "כ", "ל"];

        if (num < 1 || num > 30)
            return num.toString();

        // Special cases for 15 and 16 to avoid writing God's name (יה and יו)
        if (num === 15) return "ט״ו";  // tet-vav (9+6) instead of yod-hey (10+5)
        if (num === 16) return "ט״ז";  // tet-zayin (9+7) instead of yod-vav (10+6)

        var tensDigit = Math.floor(num / 10);
        var onesDigit = num % 10;

        var result = tens[tensDigit] + ones[onesDigit];

        // Add geresh or gershayim
        if (result.length === 1) {
            result += "׳";
        } else if (result.length > 1) {
            result = result.slice(0, -1) + "״" + result.slice(-1);
        }

        return result;
    }
    function convertWeekdayToHebrew(weekdayAbbrev) {
        var weekdayMap = {
            "Sun": "א",
            "Mon": "ב",
            "Tue": "ג",
            "Wed": "ד",
            "Thu": "ה",
            "Fri": "ו",
            "Sat": "שבת"
        };
        return weekdayMap[weekdayAbbrev] || weekdayAbbrev;
    }
    function convertYearToHebrew(yearNum) {
        // Simple conversion - for proper year conversion would need more complex logic
        // For now, just add ה׳ prefix to indicate it's a year
        return "ה׳" + yearNum;
    }
    function formatDate() {
        // Replace template placeholders with actual values
        var result = displayTemplate;
        result = result.replace(/{day}/g, hebrewDay);
        result = result.replace(/{month}/g, hebrewMonth);
        result = result.replace(/{year}/g, hebrewYear);
        result = result.replace(/{weekday}/g, hebrewWeekday);
        return result;
    }
    function formatTooltip() {
        var tooltip = hebrewDay + " " + hebrewMonth + " " + hebrewYear;
        if (isHoliday && holidayName) {
            tooltip += "\n" + holidayName;
        }
        return tooltip;
    }
    function parseHebrewDate(output) {
        // Parse hebcal output
        // Example Hebrew output: "יום ראשון ד׳ בטבת ה׳תשפ״ה"
        // Example English output: "Sunday, 4 Tevet 5785"
        // Example Ashkenazi: "Shushan Purim, 15 Adar II 5784"

        console.log("Hebrew Calendar: Parsing hebcal output:", output);

        // Check if it's Hebrew output (contains Hebrew characters)
        var isHebrew = /[\u0590-\u05FF]/.test(output);

        if (isHebrew) {
            // Parse Hebrew format from hebcal -T -w: "Sun, ט״ו טבת תשפ״ו"
            // Format: EnglishWeekdayAbbrev, day month year
            var parts = output.split(" ");

            if (parts.length >= 4) {
                // parts[0] = weekday abbreviation with comma (e.g., "Sun,")
                // parts[1] = day number with geresh/gershayim (e.g., ט״ו)
                // parts[2] = month name (e.g., טבת)
                // parts[3] = year (e.g., תשפ״ו)

                var weekdayEn = parts[0].replace(",", "");
                root.hebrewWeekday = convertWeekdayToHebrew(weekdayEn);
                root.hebrewDay = parts[1];
                root.hebrewMonth = parts[2];
                root.hebrewYear = parts[3];

                console.log("Hebrew Calendar: Parsed Hebrew -", "weekday:", root.hebrewWeekday, "day:", root.hebrewDay, "month:", root.hebrewMonth, "year:", root.hebrewYear);
            } else {
                console.log("Hebrew Calendar: Unexpected Hebrew format, got", parts.length, "parts:", output);
            }
        } else {
            // Parse English format from hebcal -T -w: "Sun, 15th of Tevet, 5786"
            // Format: WeekdayAbbrev, DayOrdinal of Month, Year

            // Try to match: "Sun, 15th of Tevet, 5786"
            var match = output.match(/(\w+),\s+(\d+)\w*\s+of\s+(\w+(?:\s+\w+)?),\s+(\d+)/);
            if (match) {
                root.hebrewWeekday = convertWeekdayToHebrew(match[1]);
                var dayNum = parseInt(match[2]);
                root.hebrewDay = convertToHebrewNumeral(dayNum);
                root.hebrewMonth = convertMonthToHebrew(match[3].trim());
                root.hebrewYear = convertYearToHebrew(match[4]);

                console.log("Hebrew Calendar: Parsed English -", "weekday:", root.hebrewWeekday, "day:", root.hebrewDay, "month:", root.hebrewMonth, "year:", root.hebrewYear);
            } else {
                console.log("Hebrew Calendar: Failed to match date pattern in:", output);
            }
        }
    }
    function updateHebrewDate() {
        hebcalProcess.running = true;
    }

    color: "transparent"
    implicitHeight: barIsVertical ? dateText.implicitHeight : Style.barHeight
    implicitWidth: barIsVertical ? Style.barHeight : dateText.implicitWidth

    Component.onCompleted: {
        console.log("Hebrew Calendar bar widget loaded");
        console.log("Settings - city:", city, "israeli:", israeli, "language:", language, "template:", displayTemplate, "font:", fontFamily);
        updateHebrewDate();
    }

    // Hebrew date text
    NText {
        id: dateText

        LayoutMirroring.enabled: true
        anchors.centerIn: parent
        color: Color.mOnSurface
        font.family: fontFamily
        pointSize: Style.fontSizeM
        text: {
            var result = formatDate();
            console.log("Hebrew Calendar: Displaying text:", result, "length:", result.length);
            return result || "---"; // Show placeholder if empty
        }

        // Click to open panel
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (pluginApi) {
                    pluginApi.openPanel(root.screen);
                }
            }
        }
    }

    // Update timer - refresh every hour
    Timer {
        interval: 3600000  // 1 hour in milliseconds
        repeat: true
        running: true

        onTriggered: {
            updateHebrewDate();
        }
    }

    // Process to get Hebrew date using hebcal command
    Process {
        id: hebcalProcess

        command: ["bash", "-c", buildHebcalCommand()]

        stderr: SplitParser {
            onRead: function (data) {
                console.log("Hebrew Calendar: hebcal stderr:", data);
            }
        }
        stdout: SplitParser {
            onRead: function (data) {
                try {
                    console.log("Hebrew Calendar: Raw hebcal output:", data);
                    if (data && data.trim()) {
                        parseHebrewDate(data.trim());
                    } else {
                        console.log("Hebrew Calendar: Empty output from hebcal");
                    }
                } catch (e) {
                    console.log("Hebrew Calendar: Error parsing date:", e);
                }
            }
        }

        onExited: function (exitCode, exitStatus) {
            console.log("Hebrew Calendar: hebcal exited with code:", exitCode, "status:", exitStatus);
        }
    }
}
