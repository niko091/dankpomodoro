import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "Pomodoro.js" as Logic

Item {
    id: chart
    property string pluginId: "dankPomodoroTimerPlusPlus"
    property var bars: []
    property color barColor: Theme.primary
    property color labelColor: Theme.surfaceVariantText
    readonly property var weekdays: [I18n.trFor("dankPomodoroTimerPlusPlus", "Sunday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Monday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Tuesday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Wednesday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Thursday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Friday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Saturday")]
    readonly property var months: [I18n.trFor("dankPomodoroTimerPlusPlus", "Jan"), I18n.trFor("dankPomodoroTimerPlusPlus", "Feb"), I18n.trFor("dankPomodoroTimerPlusPlus", "Mar"), I18n.trFor("dankPomodoroTimerPlusPlus", "Apr"), I18n.trFor("dankPomodoroTimerPlusPlus", "May"), I18n.trFor("dankPomodoroTimerPlusPlus", "Jun"), I18n.trFor("dankPomodoroTimerPlusPlus", "Jul"), I18n.trFor("dankPomodoroTimerPlusPlus", "Aug"), I18n.trFor("dankPomodoroTimerPlusPlus", "Sep"), I18n.trFor("dankPomodoroTimerPlusPlus", "Oct"), I18n.trFor("dankPomodoroTimerPlusPlus", "Nov"), I18n.trFor("dankPomodoroTimerPlusPlus", "Dec")]
    readonly property real maximum: Math.max(5, Math.ceil(Logic.Pomodoro.maxMinutes(bars) / 5) * 5)
    readonly property real plotWidth: Math.max(1, width - 62)
    readonly property real plotHeight: Math.max(1, height - 68)
    property int hoveredIndex: -1
    Accessible.role: Accessible.Chart
    Accessible.name: I18n.trFor("dankPomodoroTimerPlusPlus", "Work minutes by period")

    function labelFor(bar) {
        if (bar.weekdayIndex !== undefined)
            return weekdays[bar.weekdayIndex];
        if (bar.monthIndex >= 0)
            return months[bar.monthIndex];
        return bar.label;
    }

    onBarsChanged: plot.requestPaint()
    onWidthChanged: plot.requestPaint()
    onHeightChanged: plot.requestPaint()
    onBarColorChanged: plot.requestPaint()
    onLabelColorChanged: plot.requestPaint()
    onWeekdaysChanged: plot.requestPaint()
    onMonthsChanged: plot.requestPaint()

    Canvas {
        id: plot
        renderStrategy: Canvas.Cooperative
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.font = Theme.fontSizeSmall + "px sans-serif";
            ctx.textAlign = "right";
            ctx.textBaseline = "middle";
            for (let tick = 0; tick <= 5; tick++) {
                const y = 12 + chart.plotHeight - tick * chart.plotHeight / 5;
                ctx.strokeStyle = Qt.alpha(chart.labelColor, 0.13);
                ctx.beginPath();
                ctx.moveTo(48, y);
                ctx.lineTo(48 + chart.plotWidth, y);
                ctx.stroke();
                ctx.fillStyle = chart.labelColor;
                ctx.fillText(String(Math.round(chart.maximum * tick / 5)), 40, y);
            }
            const step = chart.plotWidth / Math.max(1, chart.bars.length);
            const stride = Math.max(1, Math.ceil(chart.bars.length / 9));
            for (let index = 0; index < chart.bars.length; index++) {
                const bar = chart.bars[index];
                const x = 48 + index * step;
                const barHeight = bar.minutes / chart.maximum * chart.plotHeight;
                ctx.fillStyle = Qt.alpha(chart.barColor, bar.current ? 1 : 0.8);
                if (bar.minutes > 0)
                    ctx.fillRect(x + Math.min(2, step * 0.12), 12 + chart.plotHeight - barHeight, Math.max(1, step * 0.76), barHeight);
                if (index % stride === 0 || index === chart.bars.length - 1) {
                    ctx.save();
                    ctx.translate(x + step / 2, 24 + chart.plotHeight);
                    ctx.rotate(-Math.PI / 5);
                    ctx.fillStyle = chart.labelColor;
                    ctx.textAlign = "right";
                    ctx.fillText(chart.labelFor(bar), 0, 0);
                    ctx.restore();
                }
            }
        }
    }
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: mouse => {
            chart.hoveredIndex = mouse.x >= 48 && mouse.x <= 48 + chart.plotWidth && mouse.y <= 12 + chart.plotHeight ? Math.min(chart.bars.length - 1, Math.floor((mouse.x - 48) / chart.plotWidth * chart.bars.length)) : -1;
        }
        onExited: chart.hoveredIndex = -1
    }
    StyledRect {
        visible: chart.hoveredIndex >= 0 && chart.hoveredIndex < chart.bars.length
        width: tooltip.implicitWidth + 20
        height: tooltip.implicitHeight + 14
        x: Math.max(0, Math.min(chart.width - width, hoverArea.mouseX - width / 2))
        y: Math.max(0, hoverArea.mouseY - height - 12)
        color: Theme.surfaceContainerHighest
        radius: 8
        StyledText {
            id: tooltip
            anchors.centerIn: parent
            text: {
                const bar = chart.bars[chart.hoveredIndex];
                return bar ? I18n.trFor("dankPomodoroTimerPlusPlus", "%1: %2 min").arg(bar.weekdayIndex !== undefined ? chart.labelFor(bar) : bar.key).arg(bar.minutes) : "";
            }
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
