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
    property int streakMinimumMinutes: 1
    property string grouping: "days"
    property int chartPage: 0
    property real preferredContentHeight: SettingsMetrics.windowHeight
    readonly property string windowTitle: I18n.trFor("dankPomodoroTimerPlusPlus", "Pomodoro Dashboard")
    readonly property var summary: Logic.Pomodoro.dashboardSummary(history, sessionStats, today, dailyGoalMinutes, streakMinimumMinutes)
    readonly property var chartData: Logic.Pomodoro.dashboardChart(history, today, grouping, chartPage)
    readonly property bool canGoBack: Logic.Pomodoro.dashboardHasEarlier(history, chartData, grouping)
    readonly property var weekdayNames: [I18n.trFor("dankPomodoroTimerPlusPlus", "Sunday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Monday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Tuesday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Wednesday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Thursday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Friday"), I18n.trFor("dankPomodoroTimerPlusPlus", "Saturday")]
    onGroupingChanged: chartPage = 0
    function daysLabel(days) {
        return (days === 1 ? I18n.trFor("dankPomodoroTimerPlusPlus", "%1 day") : I18n.trFor("dankPomodoroTimerPlusPlus", "%1 days")).arg(days);
    }
    function sessionsLabel(count) {
        return (count === 1 ? I18n.trFor("dankPomodoroTimerPlusPlus", "%1 recorded session") : I18n.trFor("dankPomodoroTimerPlusPlus", "%1 recorded sessions")).arg(count);
    }
    function weekComparison(change) {
        return change === null ? "" : I18n.trFor("dankPomodoroTimerPlusPlus", "%1% vs last week").arg((change > 0 ? "+" : "") + change);
    }
    positioning: "center"
    modalWidth: Math.min(SettingsMetrics.windowWidth, Math.max(320, screenWidth - Theme.spacingL * 2))
    modalHeight: Math.min(preferredContentHeight, SettingsMetrics.windowHeight, Math.max(320, screenHeight - SettingsMetrics.pagePaddingH * 2 - Theme.spacingL))
    onBackgroundClicked: close()

    content: Component {
        Item {
            id: page
            implicitHeight: heading.y + heading.height + 16 + dashboardColumn.implicitHeight + 24
            focus: true
            Binding {
                target: dashboard
                property: "preferredContentHeight"
                value: page.implicitHeight
            }
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
                    tooltipText: I18n.trFor("dankPomodoroTimerPlusPlus", "Close")
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
                        columns: Math.max(1, Math.min(4, Math.floor((width + spacing) / 266)))
                        spacing: 16
                        property real cardWidth: (width - spacing * (columns - 1)) / columns
                        DashboardStatCard {
                            objectName: "weeklyMinutesCard"
                            width: parent.cardWidth
                            iconName: "schedule"
                            title: I18n.trFor("dankPomodoroTimerPlusPlus", "Minutes this week")
                            value: String(dashboard.summary.weekMinutes)
                            comparisonBadge: true
                            comparisonChange: dashboard.summary.weekChange
                            detail: comparisonChange === null ? I18n.trFor("dankPomodoroTimerPlusPlus", "— vs last week") : dashboard.weekComparison(comparisonChange)
                        }
                        DashboardStatCard {
                            objectName: "weeklySessionsCard"
                            width: parent.cardWidth
                            iconName: "stacks"
                            accent: Theme.secondary
                            title: I18n.trFor("dankPomodoroTimerPlusPlus", "Sessions this week")
                            value: dashboard.sessionStats.trackingSince ? String(dashboard.summary.sessionsThisWeek) : "—"
                            detail: dashboard.weekComparison(dashboard.summary.sessionsWeekChange)
                        }
                        DashboardStatCard {
                            width: parent.cardWidth
                            iconName: "hourglass_top"
                            objectName: "averageSessionCard"
                            accent: Theme.info
                            title: I18n.trFor("dankPomodoroTimerPlusPlus", "Average session length")
                            value: dashboard.summary.averageMinutes !== null ? I18n.trFor("dankPomodoroTimerPlusPlus", "%1 min").arg(dashboard.summary.averageMinutes) : "—"
                        }
                        DashboardStatCard {
                            width: parent.cardWidth
                            iconName: "target"
                            objectName: "monthlyGoalsCard"
                            accent: Theme.warning
                            title: I18n.trFor("dankPomodoroTimerPlusPlus", "Goals hit this month")
                            value: dashboard.dailyGoalMinutes > 0 ? dashboard.daysLabel(dashboard.summary.goalsHit) : "—"
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
                                    text: I18n.trFor("dankPomodoroTimerPlusPlus", "Productivity insights")
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
                                    title: I18n.trFor("dankPomodoroTimerPlusPlus", "Peak hour")
                                    value: dashboard.summary.peakHour !== null ? String(dashboard.summary.peakHour).padStart(2, "0") + ":00" : "—"
                                    iconName: "schedule"
                                }
                                DashboardStatCard {
                                    compact: true
                                    width: parent.cardWidth
                                    title: I18n.trFor("dankPomodoroTimerPlusPlus", "Best day")
                                    value: dashboard.summary.bestWeekday !== null ? dashboard.weekdayNames[dashboard.summary.bestWeekday] : "—"
                                    iconName: "event_available"
                                }
                                DashboardStatCard {
                                    compact: true
                                    width: parent.cardWidth
                                    title: I18n.trFor("dankPomodoroTimerPlusPlus", "Current streak")
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
                                    text: I18n.trFor("dankPomodoroTimerPlusPlus", "Focus time breakdown")
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.DemiBold
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Repeater {
                                    model: [
                                        {
                                            key: "days",
                                            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Days")
                                        },
                                        {
                                            key: "weeks",
                                            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Weeks")
                                        },
                                        {
                                            key: "months",
                                            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Months")
                                        },
                                        {
                                            key: "years",
                                            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Years")
                                        },
                                        {
                                            key: "weekday",
                                            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Weekday")
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
                                visible: dashboard.grouping === "years"
                                spacing: 8
                                DButton {
                                    id: previousButton
                                    visible: dashboard.grouping === "years"
                                    text: I18n.trFor("dankPomodoroTimerPlusPlus", "Previous")
                                    iconName: "chevron_left"
                                    variant: "text"
                                    buttonHeight: 32
                                    enabled: dashboard.canGoBack
                                    onClicked: dashboard.chartPage++
                                }
                                Item {
                                    width: Math.max(0, parent.width - (previousButton.visible ? previousButton.width + 8 : 0) - (nextButton.visible ? nextButton.width + 8 : 0))
                                }
                                DButton {
                                    id: nextButton
                                    visible: dashboard.grouping === "years"
                                    text: I18n.trFor("dankPomodoroTimerPlusPlus", "Next")
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
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 16
                            width: Math.min(parent.width - 32, totalHours.implicitWidth + totalMinutes.implicitWidth + totalSessions.implicitWidth + spacing * 2)
                            spacing: 24
                            StyledText {
                                id: totalHours
                                text: I18n.trFor("dankPomodoroTimerPlusPlus", "%1 total hours").arg((dashboard.summary.totalMinutes / 60).toFixed(1))
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            StyledText {
                                id: totalMinutes
                                text: I18n.trFor("dankPomodoroTimerPlusPlus", "%1 total minutes").arg(dashboard.summary.totalMinutes)
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                            StyledText {
                                id: totalSessions
                                text: dashboard.sessionsLabel(dashboard.summary.totalSessions)
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeMedium
                            }
                        }
                    }
                }
            }
        }
    }
}
