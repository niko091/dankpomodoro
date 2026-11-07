import QtQuick
import QtQuick.Controls as Controls
import qs.Common
import qs.Modals.Common
import qs.Modules.Settings.Widgets
import qs.DCommon.Widgets
import "Pomodoro.js" as Logic

DModal {
    id: dashboard
    property string pluginId: "dankPomodoroTimerPlusPlus"
    property var history: ({})
    property var sessionStats: Logic.Pomodoro.cleanSessionStats({})
    property var today: new Date()
    property int dailyGoalMinutes: 60
    property string grouping: "days"
    property int chartPage: 0
    readonly property string windowTitle: I18n.trFor(pluginId, "Pomodoro Dashboard")
    readonly property var summary: Logic.Pomodoro.dashboardSummary(history, sessionStats, today, dailyGoalMinutes)
    readonly property var chartData: Logic.Pomodoro.dashboardChart(history, today, grouping, chartPage)
    readonly property bool canGoBack: Logic.Pomodoro.dashboardHasEarlier(history, chartData, grouping)
    readonly property var weekdayNames: [I18n.trFor(pluginId, "Sunday"), I18n.trFor(pluginId, "Monday"), I18n.trFor(pluginId, "Tuesday"), I18n.trFor(pluginId, "Wednesday"), I18n.trFor(pluginId, "Thursday"), I18n.trFor(pluginId, "Friday"), I18n.trFor(pluginId, "Saturday")]
    onGroupingChanged: chartPage = 0
    function daysLabel(days) {
        return (days === 1 ? I18n.trFor(pluginId, "%1 day") : I18n.trFor(pluginId, "%1 days")).arg(days);
    }
    function sessionsLabel(count) {
        return (count === 1 ? I18n.trFor(pluginId, "%1 recorded session") : I18n.trFor(pluginId, "%1 recorded sessions")).arg(count);
    }
    positioning: "center"
    modalWidth: Math.min(SettingsMetrics.windowWidth, Math.max(320, screenWidth - Theme.spacingL * 2))
    modalHeight: Math.min(SettingsMetrics.windowHeight, Math.max(320, screenHeight - SettingsMetrics.pagePaddingH * 2 - Theme.spacingL))
    onBackgroundClicked: close()

    content: Component {
        Item {
            id: page
            focus: true
            Keys.onEscapePressed: dashboard.close()
            Item {
                id: heading
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                height: 48
                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: dashboard.windowTitle
                    color: Theme.surfaceText
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                }
                PomodoroIconButton {
                    objectName: "closeDashboardButton"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    controlSize: 36
                    iconName: "close"
                    tooltipText: I18n.trFor(dashboard.pluginId, "Close")
                    onClicked: dashboard.close()
                }
            }
            Flickable {
                anchors.top: heading.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                anchors.topMargin: 16
                clip: true
                contentWidth: width
                contentHeight: dashboardColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {}
                Column {
                    id: dashboardColumn
                    width: parent.width
                    spacing: 20
                    Grid {
                        width: parent.width
                        columns: width >= 850 ? 4 : 2
                        spacing: 16
                        property real cardWidth: (width - spacing * (columns - 1)) / columns
                        DashboardStatCard {
                            width: parent.cardWidth
                            iconName: "schedule"
                            title: I18n.trFor(dashboard.pluginId, "Minutes this week")
                            value: String(dashboard.summary.weekMinutes)
                            detail: dashboard.summary.weekChange !== null ? I18n.trFor(dashboard.pluginId, "%1% vs last week").arg((dashboard.summary.weekChange > 0 ? "+" : "") + dashboard.summary.weekChange) : dashboard.summary.weekMinutes > 0 ? I18n.trFor(dashboard.pluginId, "New activity this week") : I18n.trFor(dashboard.pluginId, "No change from last week")
                        }
                        DashboardStatCard {
                            width: parent.cardWidth
                            iconName: "stacks"
                            accent: Theme.secondary
                            title: I18n.trFor(dashboard.pluginId, "Sessions this week")
                            value: dashboard.sessionStats.trackingSince ? String(dashboard.summary.sessionsThisWeek) : "—"
                            detail: dashboard.sessionsLabel(dashboard.summary.totalSessions)
                        }
                        DashboardStatCard {
                            width: parent.cardWidth
                            iconName: "hourglass_top"
                            accent: Theme.info
                            title: I18n.trFor(dashboard.pluginId, "Average session length")
                            value: dashboard.summary.averageMinutes !== null ? I18n.trFor(dashboard.pluginId, "%1 min").arg(dashboard.summary.averageMinutes) : "—"
                            detail: I18n.trFor(dashboard.pluginId, "Your typical focus time")
                        }
                        DashboardStatCard {
                            width: parent.cardWidth
                            iconName: "target"
                            accent: Theme.warning
                            title: I18n.trFor(dashboard.pluginId, "Goals hit this month")
                            value: dashboard.dailyGoalMinutes > 0 ? dashboard.daysLabel(dashboard.summary.goalsHit) : "—"
                            detail: dashboard.dailyGoalMinutes > 0 ? I18n.trFor(dashboard.pluginId, "%1 min daily goal").arg(dashboard.dailyGoalMinutes) : I18n.trFor(dashboard.pluginId, "Set a daily goal in settings")
                        }
                    }
                    StyledRect {
                        width: parent.width
                        height: insightsColumn.implicitHeight + 32
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        Column {
                            id: insightsColumn
                            x: 16
                            y: 16
                            width: parent.width - 32
                            spacing: 16
                            Row {
                                spacing: 8
                                DIcon {
                                    name: "lightbulb"
                                    size: 20
                                    color: Theme.warning
                                }
                                StyledText {
                                    text: I18n.trFor(dashboard.pluginId, "Productivity insights")
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                }
                            }
                            Grid {
                                width: parent.width
                                columns: width >= 650 ? 3 : 1
                                spacing: 12
                                property real cardWidth: (width - spacing * (columns - 1)) / columns
                                DashboardStatCard {
                                    compact: true
                                    width: parent.cardWidth
                                    title: I18n.trFor(dashboard.pluginId, "Peak hour")
                                    value: dashboard.summary.peakHour !== null ? String(dashboard.summary.peakHour).padStart(2, "0") + ":00" : "—"
                                    iconName: "schedule"
                                }
                                DashboardStatCard {
                                    compact: true
                                    width: parent.cardWidth
                                    title: I18n.trFor(dashboard.pluginId, "Best day")
                                    value: dashboard.summary.bestWeekday !== null ? dashboard.weekdayNames[dashboard.summary.bestWeekday] : "—"
                                    iconName: "event_available"
                                }
                                DashboardStatCard {
                                    compact: true
                                    width: parent.cardWidth
                                    title: I18n.trFor(dashboard.pluginId, "Current streak")
                                    value: dashboard.daysLabel(dashboard.summary.streakDays)
                                    iconName: "local_fire_department"
                                }
                            }
                        }
                    }
                    StyledRect {
                        width: parent.width
                        height: graphColumn.implicitHeight + 32
                        color: Theme.surfaceContainerHigh
                        radius: Theme.cornerRadius
                        Column {
                            id: graphColumn
                            x: 16
                            y: 16
                            width: parent.width - 32
                            spacing: 16
                            Flow {
                                width: parent.width
                                spacing: 8
                                StyledText {
                                    height: 32
                                    text: I18n.trFor(dashboard.pluginId, "Focus time breakdown")
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Repeater {
                                    model: [
                                        {
                                            key: "days",
                                            text: I18n.trFor(dashboard.pluginId, "Days")
                                        },
                                        {
                                            key: "weeks",
                                            text: I18n.trFor(dashboard.pluginId, "Weeks")
                                        },
                                        {
                                            key: "months",
                                            text: I18n.trFor(dashboard.pluginId, "Months")
                                        },
                                        {
                                            key: "years",
                                            text: I18n.trFor(dashboard.pluginId, "Years")
                                        },
                                        {
                                            key: "weekday",
                                            text: I18n.trFor(dashboard.pluginId, "Weekday")
                                        }
                                    ]
                                    DButton {
                                        required property var modelData
                                        objectName: "dashboard-group-" + modelData.key
                                        text: modelData.text
                                        variant: dashboard.grouping === modelData.key ? "tonal" : "text"
                                        buttonHeight: 32
                                        wrapText: false
                                        onClicked: dashboard.grouping = modelData.key
                                    }
                                }
                            }
                            FocusChart {
                                id: focusChart
                                objectName: "dashboardChart"
                                width: parent.width
                                height: 260
                                pluginId: dashboard.pluginId
                                bars: dashboard.chartData
                            }
                            Row {
                                width: parent.width
                                spacing: 8
                                DButton {
                                    id: previousButton
                                    visible: dashboard.grouping === "years"
                                    text: I18n.trFor(dashboard.pluginId, "Previous")
                                    iconName: "chevron_left"
                                    variant: "text"
                                    buttonHeight: 32
                                    enabled: dashboard.canGoBack
                                    onClicked: dashboard.chartPage++
                                }
                                StyledText {
                                    width: Math.max(0, parent.width - (previousButton.visible ? previousButton.width + 8 : 0) - (nextButton.visible ? nextButton.width + 8 : 0))
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: dashboard.grouping === "weekday" ? I18n.trFor(dashboard.pluginId, "All recorded days") : dashboard.chartData[0].key + " — " + dashboard.chartData[dashboard.chartData.length - 1].key
                                    horizontalAlignment: Text.AlignHCenter
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                                DButton {
                                    id: nextButton
                                    visible: dashboard.grouping === "years"
                                    text: I18n.trFor(dashboard.pluginId, "Next")
                                    iconName: "chevron_right"
                                    variant: "text"
                                    buttonHeight: 32
                                    enabled: dashboard.chartPage > 0
                                    onClicked: dashboard.chartPage--
                                }
                            }
                        }
                    }
                    StyledRect {
                        width: parent.width
                        height: totals.implicitHeight + 32
                        color: Theme.surfaceContainerHigh
                        radius: Theme.cornerRadius
                        Flow {
                            id: totals
                            x: 16
                            y: 16
                            width: parent.width - 32
                            spacing: 24
                            StyledText {
                                text: I18n.trFor(dashboard.pluginId, "%1 total hours").arg((dashboard.summary.totalMinutes / 60).toFixed(1))
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            StyledText {
                                text: I18n.trFor(dashboard.pluginId, "%1 total minutes").arg(dashboard.summary.totalMinutes)
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            StyledText {
                                text: dashboard.sessionsLabel(dashboard.summary.totalSessions)
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                        }
                    }
                    StyledText {
                        width: parent.width
                        text: dashboard.sessionStats.trackingSince ? I18n.trFor(dashboard.pluginId, "Session counts, averages and peak hour are tracked from %1.").arg(dashboard.sessionStats.trackingSince) : I18n.trFor(dashboard.pluginId, "Record a session to start tracking session statistics.")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
