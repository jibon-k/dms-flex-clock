import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "FlexFormat.js" as Fmt

PluginComponent {
    id: root

    layerNamespacePlugin: "flexClock"

    // ─── Settings ───
    readonly property real ampmScale: (pluginData.ampmScale ?? 65) / 100
    readonly property real dateScale: (pluginData.dateScale ?? 100) / 100
    readonly property bool showTime: pluginData.showTime ?? true
    readonly property bool showDate: pluginData.showDate ?? true
    readonly property bool dateFirst: pluginData.dateFirst ?? false
    readonly property bool dateAccent: pluginData.dateAccent ?? true
    readonly property bool showSeparator: pluginData.showSeparator ?? true
    readonly property string clickAction: pluginData.clickAction ?? "dash"
    readonly property string rightClickAction: pluginData.rightClickAction ?? "card"
    readonly property string clickCommand: pluginData.clickCommand ?? ""

    // ─── Effective formats (presets → custom → DMS settings) ───
    readonly property string autoVTime: {
        let f = "hh|mm";
        if (SettingsData.showSeconds)
            f += "|ss";
        if (!SettingsData.use24HourClock && SettingsData.showAmPm)
            f += "|AP";
        return f;
    }
    readonly property string vTimeFormat: Fmt.resolve(pluginData.verticalTimePreset, pluginData.verticalTimeFormat, autoVTime)
    readonly property string vDateFormat: Fmt.resolve(pluginData.verticalDatePreset, pluginData.verticalDateFormat, "d|MMM")
    readonly property string hTimeFormat: Fmt.resolve(pluginData.timePreset, pluginData.timeFormat, SettingsData.getEffectiveTimeFormat())
    readonly property string hDateFormat: Fmt.resolve(pluginData.datePreset, pluginData.dateFormat, SettingsData.getEffectiveDateFormat())

    readonly property bool needsSeconds: Fmt.hasSeconds(isVertical ? vTimeFormat : hTimeFormat)

    property var locale: I18n.locale()
    property date now: systemClock.date

    readonly property color timeColor: Theme.widgetTextColor
    readonly property color dateColor: dateAccent ? Theme.primary : Theme.widgetTextColor

    readonly property var hTimeLines: Fmt.formatLines(hTimeFormat, now, locale)
    readonly property var hDateLines: Fmt.formatLines(hDateFormat, now, locale)
    readonly property var vTimeLines: Fmt.formatLines(vTimeFormat, now, locale)
    readonly property var vDateLines: Fmt.formatLines(vDateFormat, now, locale)

    // ─── Click handling ───
    // Left click: dashboard / date card / command / nothing.
    // Right click: date card / dashboard / nothing.
    readonly property var _clickHandler: (x, y, width, section, screen) => root.runAction(root.clickAction, x, y, width, section, screen)

    pillClickAction: clickAction === "card" ? null : _clickHandler
    pillRightClickAction: (x, y, width, section, screen) => root.runAction(root.rightClickAction, x, y, width, section, screen)

    function runAction(action, x, y, width, section, screen) {
        switch (action) {
        case "none":
            return;
        case "command":
            if (clickCommand)
                Quickshell.execDetached(["sh", "-c", clickCommand]);
            return;
        case "card":
            openCard();
            return;
        default:
            PopoutService.toggleDankDash(0, x, y, width, section, screen);
        }
    }

    // triggerPopout() runs pillClickAction when one is set, so clear it for
    // the call and then restore the binding.
    function openCard() {
        pillClickAction = null;
        triggerPopout();
        pillClickAction = Qt.binding(() => root.clickAction === "card" ? null : root._clickHandler);
    }

    // ─── Bar text ───
    component ClockLine: Item {
        id: lineItem

        property var segments: []
        property real fontSize: root.textSize
        property color color: root.timeColor
        property real maxWidth: 0   // 0 = unconstrained

        readonly property real fit: maxWidth > 0 && row.implicitWidth > maxWidth ? maxWidth / row.implicitWidth : 1

        implicitWidth: row.implicitWidth * fit
        implicitHeight: row.implicitHeight * fit

        FontMetrics {
            id: metrics
            font.family: Theme.fontFamily
            font.pixelSize: lineItem.fontSize
        }

        Row {
            id: row
            anchors.centerIn: parent
            scale: lineItem.fit
            baselineOffset: metrics.ascent
            LayoutMirroring.enabled: false

            Repeater {
                model: lineItem.segments

                StyledText {
                    required property var modelData
                    anchors.baseline: parent.baseline
                    text: modelData.text
                    color: modelData.accent ? Theme.primary : lineItem.color
                    opacity: modelData.dim ? 0.55 : 1
                    font.pixelSize: modelData.small ? Math.round(lineItem.fontSize * root.ampmScale) : lineItem.fontSize
                    font.weight: modelData.bold ? Theme.fontWeightBold : Theme.fontWeight
                }
            }
        }
    }

    component LineStack: Column {
        id: stack

        property var lines: []
        property real fontSize: root.textSize
        property color color: root.timeColor
        property real maxWidth: 0

        spacing: 0

        Repeater {
            model: stack.lines

            ClockLine {
                required property var modelData
                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                segments: modelData
                fontSize: stack.fontSize
                color: stack.color
                maxWidth: stack.maxWidth
            }
        }
    }

    // ─── Horizontal bar ───
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            LayoutMirroring.enabled: false

            LineStack {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.dateFirst ? root.showDate : root.showTime
                lines: root.dateFirst ? root.hDateLines : root.hTimeLines
                fontSize: root.dateFirst ? Math.round(root.textSize * root.dateScale) : root.textSize
                color: root.dateFirst ? root.dateColor : root.timeColor
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showSeparator && root.showTime && root.showDate
                text: "•"
                color: Theme.outlineButton
                font.pixelSize: Theme.fontSizeSmall
            }

            LineStack {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.dateFirst ? root.showTime : root.showDate
                lines: root.dateFirst ? root.hTimeLines : root.hDateLines
                fontSize: root.dateFirst ? root.textSize : Math.round(root.textSize * root.dateScale)
                color: root.dateFirst ? root.timeColor : root.dateColor
            }
        }
    }

    // ─── Vertical bar (left / right) ───
    verticalBarPill: Component {
        Column {
            id: vCol

            readonly property real avail: Math.max(1, root.widgetThickness - Theme.spacingXS * 2)

            width: avail
            spacing: Theme.spacingXXS

            LineStack {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.dateFirst ? root.showDate : root.showTime
                lines: root.dateFirst ? root.vDateLines : root.vTimeLines
                fontSize: root.dateFirst ? Math.round(root.textSize * root.dateScale) : root.textSize
                color: root.dateFirst ? root.dateColor : root.timeColor
                maxWidth: vCol.avail
            }

            Item {
                visible: root.showSeparator && root.showTime && root.showDate
                width: vCol.avail
                height: Theme.spacingM

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.6
                    height: 1
                    color: Theme.outlineButton
                }
            }

            LineStack {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.dateFirst ? root.showTime : root.showDate
                lines: root.dateFirst ? root.vTimeLines : root.vDateLines
                fontSize: root.dateFirst ? root.textSize : Math.round(root.textSize * root.dateScale)
                color: root.dateFirst ? root.timeColor : root.dateColor
                maxWidth: vCol.avail
            }
        }
    }

    // ─── Date card (popout) ───
    popoutWidth: 320

    popoutContent: Component {
        PopoutComponent {
            id: card

            readonly property date today: root.now
            readonly property int firstDay: (SettingsData.firstDayOfWeek >= 0 && SettingsData.firstDayOfWeek < 7) ? SettingsData.firstDayOfWeek : Qt.locale().firstDayOfWeek
            readonly property bool showWeeks: SettingsData.showWeekNumber
            property int viewYear: today.getFullYear()
            property int viewMonth: today.getMonth()
            readonly property bool viewingToday: viewYear === today.getFullYear() && viewMonth === today.getMonth()
            readonly property var cells: Fmt.monthCells(viewYear, viewMonth, firstDay)
            readonly property real cellSize: Math.floor(width / (showWeeks ? 8 : 7))

            function shiftMonth(delta) {
                const d = new Date(viewYear, viewMonth + delta, 1);
                viewYear = d.getFullYear();
                viewMonth = d.getMonth();
            }

            headerText: today.toLocaleDateString(root.locale, "dddd")
            detailsText: today.toLocaleDateString(root.locale, "d MMMM yyyy") + "  ·  Week " + Fmt.isoWeek(today) + "  ·  Day " + Fmt.dayOfYear(today)
            spacing: Theme.spacingS

            // Month header with navigation
            Item {
                width: parent.width
                height: Theme.spacingXL + Theme.spacingS

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingXS
                    text: new Date(card.viewYear, card.viewMonth, 1).toLocaleDateString(root.locale, "MMMM yyyy")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightMedium
                    color: Theme.surfaceText
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    Repeater {
                        model: [
                            { "icon": "today", "delta": 0, "show": !card.viewingToday },
                            { "icon": "chevron_left", "delta": -1, "show": true },
                            { "icon": "chevron_right", "delta": 1, "show": true }
                        ]

                        Rectangle {
                            required property var modelData
                            visible: modelData.show
                            width: Theme.spacingXL + Theme.spacingXS
                            height: width
                            radius: width / 2
                            color: navMouse.containsMouse ? Theme.chipSurface : "transparent"

                            DIcon {
                                anchors.centerIn: parent
                                name: modelData.icon
                                size: Theme.iconSizeSmall
                                color: Theme.surfaceText
                            }

                            MouseArea {
                                id: navMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.delta === 0) {
                                        card.viewYear = card.today.getFullYear();
                                        card.viewMonth = card.today.getMonth();
                                    } else {
                                        card.shiftMonth(modelData.delta);
                                    }
                                }
                            }
                        }
                    }
                }

                WheelHandler {
                    onWheel: event => card.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
                }
            }

            // Weekday initials
            Row {
                Item {
                    visible: card.showWeeks
                    width: card.cellSize
                    height: Theme.fontSizeSmall * 1.6
                }

                Repeater {
                    model: 7

                    StyledText {
                        required property int index
                        width: card.cellSize
                        horizontalAlignment: Text.AlignHCenter
                        text: root.locale.dayName((card.firstDay + index) % 7, Locale.NarrowFormat)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.surfaceVariantText
                    }
                }
            }

            // Day grid (6 weeks)
            Column {
                Repeater {
                    model: 6

                    Row {
                        id: weekRow
                        required property int index

                        StyledText {
                            visible: card.showWeeks
                            width: card.cellSize
                            height: card.cellSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: {
                                const c = card.cells[weekRow.index * 7];
                                return Fmt.isoWeek(new Date(c.year, c.month, c.day));
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.outlineButton
                        }

                        Repeater {
                            model: 7

                            Item {
                                id: dayCell
                                required property int index
                                readonly property var cell: card.cells[weekRow.index * 7 + index]
                                readonly property bool isToday: cell.day === card.today.getDate() && cell.month === card.today.getMonth() && cell.year === card.today.getFullYear()

                                width: card.cellSize
                                height: card.cellSize

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - Theme.spacingXS
                                    height: width
                                    radius: width / 2
                                    color: dayCell.isToday ? Theme.primary : "transparent"
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: dayCell.cell.day
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: dayCell.isToday ? Theme.fontWeightBold : Theme.fontWeight
                                    color: dayCell.isToday ? Theme.onPrimary : (dayCell.cell.inMonth ? Theme.surfaceText : Theme.outlineButton)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SystemClock {
        id: systemClock
        enabled: root.surfaceLive || root.interactionActive
        precision: root.needsSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Connections {
        target: SessionService
        function onSessionResumed() {
            systemClock.enabled = false;
            systemClock.enabled = Qt.binding(() => root.surfaceLive || root.interactionActive);
        }
    }
}
