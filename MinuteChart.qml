import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "Pomodoro.js" as Logic

Row {
    id: chart
    property string translationPluginId: "dankPomodoroTimerPlusPlus"
    readonly property var monthLabels: [I18n.trFor(chart.translationPluginId, "Jan"), I18n.trFor(chart.translationPluginId, "Feb"), I18n.trFor(chart.translationPluginId, "Mar"), I18n.trFor(chart.translationPluginId, "Apr"), I18n.trFor(chart.translationPluginId, "May"), I18n.trFor(chart.translationPluginId, "Jun"), I18n.trFor(chart.translationPluginId, "Jul"), I18n.trFor(chart.translationPluginId, "Aug"), I18n.trFor(chart.translationPluginId, "Sep"), I18n.trFor(chart.translationPluginId, "Oct"), I18n.trFor(chart.translationPluginId, "Nov"), I18n.trFor(chart.translationPluginId, "Dec")]
    property var bars: []
    readonly property real maximum: Logic.Pomodoro.maxMinutes(bars)
    height: 120
    spacing: Theme.spacingXS
    Repeater {
        model: chart.bars
        Item {
            required property var modelData
            width: (chart.width - chart.spacing * Math.max(0, chart.bars.length - 1)) / Math.max(1, chart.bars.length)
            height: chart.height
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.minutes === 1 ? I18n.trFor(chart.translationPluginId, "%1: 1 minute").arg(modelData.key) : I18n.trFor(chart.translationPluginId, "%1: %2 minutes").arg(modelData.key).arg(modelData.minutes)
            StyledText {
                width: parent.width
                text: modelData.minutes > 0 ? modelData.minutes : ""
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Item {
                width: parent.width
                height: Math.max(0, chart.height - 40)
                y: 20
                Rectangle {
                    width: parent.width
                    height: 2
                    anchors.bottom: parent.bottom
                    color: Qt.alpha(Theme.primary, 0.15)
                }
                Rectangle {
                    width: parent.width
                    height: modelData.minutes > 0 ? Math.max(3, modelData.minutes / chart.maximum * parent.height) : 0
                    anchors.bottom: parent.bottom
                    radius: 3
                    color: Qt.alpha(Theme.primary, modelData.current ? 1 : 0.55)
                }
            }
            StyledText {
                width: parent.width
                anchors.bottom: parent.bottom
                text: modelData.monthIndex >= 0 ? chart.monthLabels[modelData.monthIndex] : modelData.label
                color: modelData.current ? Theme.primary : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }
}
