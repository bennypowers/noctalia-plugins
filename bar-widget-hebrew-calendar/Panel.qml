import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root
    property var pluginApi: null
    property var screen: null

    // SmartPanel properties
    readonly property bool allowAttach: true
    property real contentPreferredWidth: 420 * Style.uiScaleRatio
    property real contentPreferredHeight: content.implicitHeight + (Style.marginL * 2)

    // Settings
    readonly property string city: pluginApi?.pluginSettings?.city || pluginApi?.manifest?.metadata?.defaultSettings?.city || "Jerusalem"
    readonly property bool israeli: pluginApi?.pluginSettings?.israeli !== undefined ? pluginApi.pluginSettings.israeli : (pluginApi?.manifest?.metadata?.defaultSettings?.israeli !== undefined ? pluginApi.manifest.metadata.defaultSettings.israeli : true)
    readonly property string language: pluginApi?.pluginSettings?.language || pluginApi?.manifest?.metadata?.defaultSettings?.language || "he-x-NoNikud"
    readonly property string fontFamily: pluginApi?.pluginSettings?.fontFamily || pluginApi?.manifest?.metadata?.defaultSettings?.fontFamily || "Liberation Serif"

    // Current Hebrew date
    property int currentHebrewDay: 15
    property string currentHebrewMonth: "טבת"
    property int currentHebrewYear: 5786
    property int monthLength: 29
    property int firstDayOfWeek: 0  // Day of week for the 1st of the month (0=Sunday, 6=Saturday)
    property string currentWeekday: "א"

    // Data properties
    property var zmanimList: []
    property string dafYomi: ""
    property string candleLighting: ""
    property string havdalah: ""
    property string parsha: ""

    anchors.fill: parent

    Component.onCompleted: {
        console.log("Hebrew Calendar Panel: Loading data");
        loadCurrentDate();
        loadZmanim();
        loadDafYomi();
        loadWeeklyData();
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginL

        // Hebrew Calendar Header
        HebrewCalendarHeaderCard {
            Layout.fillWidth: true
            dafYomi: root.dafYomi
            fontFamily: root.fontFamily
            hebrewDay: root.currentHebrewDay
            hebrewMonth: root.currentHebrewMonth
            hebrewWeekday: root.currentWeekday
            hebrewYear: root.currentHebrewYear
        }

        // Calendar Month
        HebrewCalendarMonthCard {
            Layout.fillWidth: true
            firstDayOfWeek: root.firstDayOfWeek
            fontFamily: root.fontFamily
            hebrewDay: root.currentHebrewDay
            hebrewMonth: root.currentHebrewMonth
            hebrewYear: root.currentHebrewYear
            monthLength: root.monthLength
        }

        // Zmanim
        ZmanimCard {
            Layout.fillWidth: true
            fontFamily: root.fontFamily
            zmanimList: root.zmanimList
        }

        // Shabbat Times
        ShabbatCard {
            Layout.fillWidth: true
            candleLighting: root.candleLighting
            fontFamily: root.fontFamily
            havdalah: root.havdalah
            parsha: root.parsha
        }
    }

    // Process to get current date
    Process {
        id: currentDateProcess

        command: ["bash", "-c", "hebcal --lang " + language + " -T -w"]

        stdout: SplitParser {
            onRead: function (data) {
                if (data && data.trim()) {
                    parseCurrentDate(data.trim());
                }
            }
        }
    }

    // Process to get zmanim
    Process {
        id: zmanimProcess

        property string outputBuffer: ""

        command: ["bash", "-c", "hebcal --lang " + language + " --city '" + city + "' " + (israeli ? "-i " : "") + "-c -Z --24hour --today"]

        stdout: SplitParser {
            onRead: function (data) {
                if (data && data.trim()) {
                    zmanimProcess.outputBuffer += data + "\n";
                }
            }
        }

        onRunningChanged: {
            if (!running && outputBuffer) {
                parseZmanim(outputBuffer);
                outputBuffer = "";
            }
        }
    }

    // Process to get Daf Yomi
    Process {
        id: dafYomiProcess

        command: ["bash", "-c", "hebcal --lang " + language + " -F --today"]

        stdout: SplitParser {
            onRead: function (data) {
                if (data && data.trim()) {
                    parseDafYomi(data.trim());
                }
            }
        }
    }

    // Process to get weekly data
    Process {
        id: weeklyDataProcess

        property string outputBuffer: ""

        command: ["bash", "-c", "hebcal --lang " + language + " --city '" + city + "' " + (israeli ? "-i " : "") + "-c -s | head -30"]

        stdout: SplitParser {
            onRead: function (data) {
                if (data && data.trim()) {
                    weeklyDataProcess.outputBuffer += data + "\n";
                }
            }
        }

        onRunningChanged: {
            if (!running && outputBuffer) {
                parseWeeklyData(outputBuffer);
                outputBuffer = "";
            }
        }
    }

    function loadCurrentDate() {
        currentDateProcess.running = true;
    }

    function loadZmanim() {
        root.zmanimList = [];
        zmanimProcess.running = true;
    }

    function loadDafYomi() {
        dafYomiProcess.running = true;
    }

    function loadWeeklyData() {
        weeklyDataProcess.running = true;
    }

    function parseCurrentDate(output) {
        // Parse "Sun, ט״ו טבת תשפ״ו"
        var parts = output.split(" ");
        if (parts.length >= 4) {
            // Parse weekday
            var weekdayAbbrev = parts[0].replace(",", "");
            var weekdayMap = {
                "Sun": 0,
                "Mon": 1,
                "Tue": 2,
                "Wed": 3,
                "Thu": 4,
                "Fri": 5,
                "Sat": 6
            };
            var weekdayHebrewMap = {
                "Sun": "א",
                "Mon": "ב",
                "Tue": "ג",
                "Wed": "ד",
                "Thu": "ה",
                "Fri": "ו",
                "Sat": "ש"
            };
            var currentDayOfWeek = weekdayMap[weekdayAbbrev] || 0;
            root.currentWeekday = weekdayHebrewMap[weekdayAbbrev] || "א";

            var dayStr = parts[1].replace(",", "");
            root.currentHebrewDay = hebrewNumeralToInt(dayStr);
            root.currentHebrewMonth = parts[2];

            // Parse year (e.g., "תשפ״ו")
            var yearStr = parts[3];
            root.currentHebrewYear = hebrewNumeralToInt(yearStr);

            // Determine month length
            var monthLengths = {
                "ניסן": 30,
                "אייר": 29,
                "סיוון": 30,
                "תמוז": 29,
                "אב": 30,
                "אלול": 29,
                "תשרי": 30,
                "חשוון": 29,
                "כסלו": 30,
                "טבת": 29,
                "שבט": 30,
                "אדר": 29
            };
            root.monthLength = monthLengths[root.currentHebrewMonth] || 29;

            // Calculate what day of the week the 1st was
            // If today is day 15 and it's Sunday (0), then we go back 14 days
            var daysBack = root.currentHebrewDay - 1;
            root.firstDayOfWeek = (currentDayOfWeek - daysBack % 7 + 7) % 7;

            console.log("Hebrew Calendar Panel: Current day:", root.currentHebrewDay, "weekday:", weekdayAbbrev, "month:", root.currentHebrewMonth, "year:", root.currentHebrewYear, "1st was on day:", root.firstDayOfWeek);
        }
    }

    function parseZmanim(output) {
        var lines = output.split("\n");
        var zmanim = [];
        var now = new Date();
        var currentMinutes = now.getHours() * 60 + now.getMinutes();

        console.log("Hebrew Calendar Panel: Current time:", now.getHours() + ":" + now.getMinutes(), "(" + currentMinutes + " minutes)");

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;

            var dateIndex = line.indexOf(" ");
            if (dateIndex > 0) {
                var content = line.substring(dateIndex + 1);
                var colonIndex = content.indexOf(":");

                if (colonIndex > 0) {
                    var name = content.substring(0, colonIndex);
                    var time = content.substring(colonIndex + 1).trim();

                    // Parse time to minutes for comparison
                    var timeParts = time.split(":");
                    var zmanMinutes = 0;
                    if (timeParts.length >= 2) {
                        zmanMinutes = parseInt(timeParts[0]) * 60 + parseInt(timeParts[1]);
                    }

                    console.log("Hebrew Calendar Panel: Parsed zman:", name, "time:", time, "minutes:", zmanMinutes);

                    zmanim.push({
                        name: name,
                        time: time,
                        minutes: zmanMinutes
                    });
                }
            }
        }

        // Determine status for each zman
        var nextZmanIndex = -1;
        for (var i = 0; i < zmanim.length; i++) {
            if (zmanim[i].minutes > currentMinutes) {
                nextZmanIndex = i;
                console.log("Hebrew Calendar Panel: Next zman is index", i, "-", zmanim[i].name);
                break;
            }
        }

        if (nextZmanIndex === -1) {
            console.log("Hebrew Calendar Panel: No future zmanim found, all have passed");
        }

        for (var i = 0; i < zmanim.length; i++) {
            if (i < nextZmanIndex || nextZmanIndex === -1) {
                zmanim[i].status = "passed";
            } else if (i === nextZmanIndex) {
                zmanim[i].status = "next";
            } else {
                zmanim[i].status = "upcoming";
            }
        }

        root.zmanimList = zmanim;
        console.log("Hebrew Calendar Panel: Loaded", zmanim.length, "zmanim");
    }

    function parseDafYomi(output) {
        var lines = output.split("\n");

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.indexOf("דף") > 0) {
                var dateIndex = line.indexOf(" ");
                if (dateIndex > 0) {
                    root.dafYomi = line.substring(dateIndex + 1);
                    console.log("Hebrew Calendar Panel: Daf Yomi:", root.dafYomi);
                    break;
                }
            }
        }
    }

    function parseWeeklyData(output) {
        var lines = output.split("\n");
        var foundCandle = false;
        var foundHavdalah = false;
        var foundParsha = false;

        var now = new Date();
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;

            var dateMatch = line.match(/^(\d+)\/(\d+)\/(\d+)/);
            if (!dateMatch) continue;

            var lineDate = new Date(parseInt(dateMatch[3]), parseInt(dateMatch[1]) - 1, parseInt(dateMatch[2]));

            if (lineDate < today) continue;

            if (!foundCandle && line.indexOf("הדלקת נרות") > 0) {
                var candleTime = line.split(":").slice(-2).join(":");
                root.candleLighting = candleTime.trim();
                foundCandle = true;
            }

            if (!foundParsha && line.indexOf("פרשת") > 0) {
                var parshaIndex = line.indexOf("פרשת");
                root.parsha = line.substring(parshaIndex);
                foundParsha = true;
            }

            if (!foundHavdalah && line.indexOf("הבדלה") > 0) {
                var havdalahTime = line.split(":").slice(-2).join(":");
                root.havdalah = havdalahTime.trim();
                foundHavdalah = true;
            }

            if (foundCandle && foundParsha && foundHavdalah) {
                break;
            }
        }

        console.log("Hebrew Calendar Panel: Parsha:", root.parsha, "Candles:", root.candleLighting, "Havdalah:", root.havdalah);
    }

    function hebrewNumeralToInt(numeral) {
        var cleaned = numeral.replace(/[׳״]/g, "");

        var ones = {
            "א": 1,
            "ב": 2,
            "ג": 3,
            "ד": 4,
            "ה": 5,
            "ו": 6,
            "ז": 7,
            "ח": 8,
            "ט": 9
        };
        var tens = {
            "י": 10,
            "כ": 20,
            "ל": 30,
            "מ": 40,
            "נ": 50,
            "ס": 60,
            "ע": 70,
            "פ": 80,
            "צ": 90
        };
        var hundreds = {
            "ק": 100,
            "ר": 200,
            "ש": 300,
            "ת": 400
        };

        var total = 0;
        for (var i = 0; i < cleaned.length; i++) {
            var ch = cleaned.charAt(i);
            if (hundreds[ch] !== undefined) {
                total += hundreds[ch];
            } else if (tens[ch] !== undefined) {
                total += tens[ch];
            } else if (ones[ch] !== undefined) {
                total += ones[ch];
            }
        }

        return total || 1;
    }
}
