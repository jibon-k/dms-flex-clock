import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "FlexFormat.js" as Fmt

PluginSettings {
    id: root
    pluginId: "flexClock"

    // ─── Live preview state (re-read from saved settings) ───
    property date now: new Date()
    property int rev: 0

    function val(key, def) {
        rev; // re-evaluate when rev changes
        const v = loadValue(key, def);
        return v === undefined || v === null ? def : v;
    }

    function previewHtml(vertical) {
        const autoVTime = "hh|mm" + (SettingsData.showSeconds ? "|ss" : "") + (!SettingsData.use24HourClock && SettingsData.showAmPm ? "|AP" : "");
        const timeFmt = vertical ? Fmt.resolve(val("verticalTimePreset", ""), val("verticalTimeFormat", ""), autoVTime) : Fmt.resolve(val("timePreset", ""), val("timeFormat", ""), SettingsData.getEffectiveTimeFormat());
        const dateFmt = vertical ? Fmt.resolve(val("verticalDatePreset", ""), val("verticalDateFormat", ""), "d|MMM") : Fmt.resolve(val("datePreset", ""), val("dateFormat", ""), SettingsData.getEffectiveDateFormat());
        const locale = I18n.locale();
        const fontPx = Theme.fontSizeLarge;
        const ampm = val("ampmScale", 65) / 100;
        const dateAccent = val("dateAccent", true);
        const base = {
            "fontPx": fontPx,
            "ampmScale": ampm,
            "vertical": vertical,
            "accentColor": String(Theme.primary),
            "dimAccentColor": String(Theme.withAlpha(Theme.primary, 0.55)),
            "color": String(Theme.surfaceText),
            "dimColor": String(Theme.withAlpha(Theme.surfaceText, 0.55))
        };
        const dateOpts = Object.assign({}, base, {
            "fontPx": Math.round(fontPx * val("dateScale", 100) / 100),
            "color": dateAccent ? base.accentColor : base.color,
            "dimColor": dateAccent ? base.dimAccentColor : base.dimColor
        });
        const showTime = val("showTime", true);
        const showDate = val("showDate", true);
        const t = showTime ? Fmt.toHtml(Fmt.formatLines(timeFmt, now, locale), base) : "";
        const d = showDate ? Fmt.toHtml(Fmt.formatLines(dateFmt, now, locale), dateOpts) : "";
        const parts = val("dateFirst", false) ? [d, t] : [t, d];
        const sep = vertical ? "<br/><span style=\"color:" + String(Theme.outlineButton) + "\">—</span><br/>" : "&nbsp;&nbsp;<span style=\"color:" + String(Theme.outlineButton) + "\">•</span>&nbsp;&nbsp;";
        return parts.filter(p => p.length).join(val("showSeparator", true) ? sep : (vertical ? "<br/>" : "&nbsp;&nbsp;"));
    }

    onSettingChanged: rev++

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date();
            root.rev++;
        }
    }

    // ─── Header ───
    StyledText {
        width: parent.width
        text: "Flex Clock"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    // ─── Preview ───
    StyledRect {
        width: parent.width
        height: previewRow.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.cardSurface

        Row {
            id: previewRow
            anchors.centerIn: parent
            spacing: Theme.spacingXL * 2

            Column {
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Left / right bar"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.RichText
                    wrapMode: Text.NoWrap
                    text: root.previewHtml(true)
                }
            }

            Column {
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Top / bottom bar"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    textFormat: Text.RichText
                    wrapMode: Text.NoWrap
                    text: root.previewHtml(false)
                }
            }
        }
    }

    // ─── Vertical bars ───
    StyledText {
        width: parent.width
        topPadding: Theme.spacingM
        text: "Left / right bar"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "verticalTimePreset"
        label: "Time"
        options: Fmt.verticalTimePresets
        defaultValue: "auto"
    }

    StringSetting {
        visible: root.val("verticalTimePreset", "") === "custom"
        settingKey: "verticalTimeFormat"
        label: "Custom time format"
        placeholder: "*hh*|mm|AP"
        defaultValue: ""
    }

    SelectionSetting {
        settingKey: "verticalDatePreset"
        label: "Date"
        options: Fmt.verticalDatePresets
        defaultValue: "d|MMM"
    }

    StringSetting {
        visible: root.val("verticalDatePreset", "") === "custom"
        settingKey: "verticalDateFormat"
        label: "Custom date format"
        placeholder: "ddd|*d*|MMM"
        defaultValue: ""
    }

    // ─── Horizontal bars ───
    StyledText {
        width: parent.width
        topPadding: Theme.spacingM
        text: "Top / bottom bar"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "timePreset"
        label: "Time"
        options: Fmt.horizontalTimePresets
        defaultValue: "auto"
    }

    StringSetting {
        visible: root.val("timePreset", "") === "custom"
        settingKey: "timeFormat"
        label: "Custom time format"
        placeholder: "*h*:mm AP"
        defaultValue: ""
    }

    SelectionSetting {
        settingKey: "datePreset"
        label: "Date"
        options: Fmt.horizontalDatePresets
        defaultValue: "auto"
    }

    StringSetting {
        visible: root.val("datePreset", "") === "custom"
        settingKey: "dateFormat"
        label: "Custom date format"
        placeholder: "ddd d !MMM!"
        defaultValue: ""
    }

    // ─── Format syntax reference ───
    property bool syntaxOpen: true
    Component.onCompleted: syntaxOpen = loadState("syntaxOpen", true)

    readonly property var syntaxGroups: [
        {
            "title": "Time",
            "icon": "schedule",
            "rows": [
                { "tok": "h", "desc": "Hour 1–12", "ex": "h|AP" },
                { "tok": "hh", "desc": "Hour 01–12", "ex": "hh|AP" },
                { "tok": "H  HH", "desc": "Hour 0–23", "ex": "HH" },
                { "tok": "mm", "desc": "Minute", "ex": "mm" },
                { "tok": "ss", "desc": "Second", "ex": "ss" },
                { "tok": "AP  ap", "desc": "AM/PM, drawn smaller", "ex": "AP" }
            ]
        },
        {
            "title": "Date",
            "icon": "calendar_today",
            "rows": [
                { "tok": "d  dd", "desc": "Day of month", "ex": "dd" },
                { "tok": "ddd", "desc": "Short weekday", "ex": "ddd" },
                { "tok": "dddd", "desc": "Weekday", "ex": "dddd" },
                { "tok": "M  MM", "desc": "Month number", "ex": "MM" },
                { "tok": "MMM", "desc": "Short month", "ex": "MMM" },
                { "tok": "MMMM", "desc": "Month", "ex": "MMMM" },
                { "tok": "yy  yyyy", "desc": "Year", "ex": "yyyy" }
            ]
        },
        {
            "title": "Layout & style",
            "icon": "format_paint",
            "rows": [
                { "tok": "|", "desc": "New line", "ex": "" },
                { "tok": "*…*", "desc": "Bold", "ex": "*d*" },
                { "tok": "~…~", "desc": "Dim", "ex": "~d~" },
                { "tok": "!…!", "desc": "Accent color", "ex": "!d!" },
                { "tok": "'…'", "desc": "Literal text", "ex": "'Week'" }
            ]
        }
    ]

    // Token chips are as wide as the widest token
    FontMetrics {
        id: chipFont
        font.family: Theme.monoFontFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    readonly property real chipWidth: {
        let w = 0;
        for (const g of syntaxGroups)
            for (const r of g.rows)
                w = Math.max(w, chipFont.advanceWidth(r.tok));
        return Math.ceil(w + Theme.spacingS * 2);
    }

    function exampleHtml(fmt) {
        rev;
        if (!fmt)
            return "";
        const lines = Fmt.formatLines(fmt, now, I18n.locale());
        if (!lines.length)
            return "";
        return Fmt.toHtml([lines[0]], {
            "fontPx": Theme.fontSizeSmall,
            "ampmScale": 1,
            "vertical": false,
            "accentColor": String(Theme.primary),
            "dimAccentColor": String(Theme.withAlpha(Theme.primary, 0.55)),
            "color": String(Theme.surfaceText),
            "dimColor": String(Theme.withAlpha(Theme.surfaceText, 0.45))
        });
    }

    StyledRect {
        id: syntaxCard
        width: parent.width
        height: syntaxCol.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.cardSurface

        Column {
            id: syntaxCol
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingM

            // Header (click to collapse)
            Item {
                width: parent.width
                height: Theme.spacingXL

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "code"
                        size: Theme.iconSizeSmall
                        color: Theme.primary
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Format syntax"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.syntaxOpen
                        text: "h:mm AP  ·  d MMM  ·  | *bold*"
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                }

                DIcon {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.syntaxOpen ? "expand_less" : "expand_more"
                    size: Theme.iconSize
                    color: Theme.surfaceVariantText
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.syntaxOpen = !root.syntaxOpen;
                        root.saveState("syntaxOpen", root.syntaxOpen);
                    }
                }
            }

            // Token groups: side by side when wide, stacked when narrow
            Flow {
                id: groupsFlow
                visible: root.syntaxOpen
                width: parent.width
                spacing: Theme.spacingL

                // A group needs room for a chip, a short description and an example
                readonly property real minGroupWidth: root.chipWidth + Theme.fontSizeSmall * 12
                readonly property int perRow: width >= 3 * minGroupWidth + 2 * spacing ? 3 : (width >= 2 * minGroupWidth + spacing ? 2 : 1)
                readonly property real groupWidth: Math.floor((width - (perRow - 1) * spacing) / perRow)

                Repeater {
                    model: root.syntaxGroups

                    Column {
                        id: group
                        required property var modelData
                        width: groupsFlow.groupWidth
                        spacing: Theme.spacingXS

                        Row {
                            spacing: Theme.spacingXS
                            bottomPadding: Theme.spacingXXS

                            DIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: group.modelData.icon
                                size: Theme.iconSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: group.modelData.title
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                color: Theme.surfaceVariantText
                            }
                        }

                        Repeater {
                            model: group.modelData.rows

                            Item {
                                id: tokRow
                                required property var modelData
                                width: group.width
                                height: Math.max(chip.height, desc.implicitHeight)

                                Rectangle {
                                    id: chip
                                    width: root.chipWidth
                                    height: chipText.implicitHeight + Theme.spacingXXS * 2
                                    radius: Theme.spacingXS
                                    color: Theme.chipSurface

                                    StyledText {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: tokRow.modelData.tok
                                        font.family: Theme.monoFontFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                    }
                                }

                                StyledText {
                                    id: desc
                                    anchors.left: chip.right
                                    anchors.leftMargin: Theme.spacingS
                                    anchors.right: example.left
                                    anchors.rightMargin: Theme.spacingXS
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tokRow.modelData.desc
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                }

                                StyledText {
                                    id: example
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    textFormat: Text.RichText
                                    wrapMode: Text.NoWrap
                                    text: root.exampleHtml(tokRow.modelData.ex)
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: root.syntaxOpen
                width: parent.width
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                text: "Example: <font face=\"" + Theme.monoFontFamily + "\" color=\"" + String(Theme.primary) + "\">ddd|*d*|!MMM!</font> → weekday, bold day, accent month on three lines. Put words in 'quotes' so their letters aren't read as tokens."
                textFormat: Text.StyledText
            }
        }
    }

    // ─── Appearance ───
    StyledText {
        width: parent.width
        topPadding: Theme.spacingM
        text: "Appearance"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "ampmScale"
        label: "AM/PM size"
        description: "Relative to the time text"
        defaultValue: 65
        minimum: 30
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "dateScale"
        label: "Date size"
        description: "Relative to the time text"
        defaultValue: 100
        minimum: 50
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "showTime"
        label: "Show time"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showDate"
        label: "Show date"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "dateFirst"
        label: "Date before time"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "dateAccent"
        label: "Date in accent color"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showSeparator"
        label: "Separator between time and date"
        defaultValue: true
    }

    // ─── Clicks ───
    StyledText {
        width: parent.width
        topPadding: Theme.spacingM
        text: "Clicks"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Theme.fontWeightMedium
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "clickAction"
        label: "Left click"
        options: [
            {
                label: "Open dashboard",
                value: "dash"
            },
            {
                label: "Show date card",
                value: "card"
            },
            {
                label: "Run command",
                value: "command"
            },
            {
                label: "Do nothing",
                value: "none"
            }
        ]
        defaultValue: "dash"
    }

    SelectionSetting {
        settingKey: "rightClickAction"
        label: "Right click"
        options: [
            {
                label: "Show date card",
                value: "card"
            },
            {
                label: "Open dashboard",
                value: "dash"
            },
            {
                label: "Do nothing",
                value: "none"
            }
        ]
        defaultValue: "card"
    }

    StringSetting {
        visible: root.val("clickAction", "dash") === "command"
        settingKey: "clickCommand"
        label: "Click command"
        placeholder: "gnome-calendar"
        defaultValue: ""
    }
}
