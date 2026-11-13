import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.DCommon.Widgets

PluginSettings {
    id: root
    pluginId: "dankPomodoroTimerPlusPlus"

    StyledText {
        objectName: "settingsTitle"
        width: parent.width
        text: I18n.trFor(root.pluginId, "Pomodoro++ Settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.trFor(root.pluginId, "Configure timer durations and behavior")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: durationsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: durationsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor(root.pluginId, "Pomodoro timers")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            PomodoroPresetsSetting {
                objectName: "timerProfilesEditor"
                width: parent.width
                settingsRoot: root
            }
        }
    }

    StyledRect {
        width: parent.width
        height: actionsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        Column {
            id: actionsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM
            StyledText {
                text: I18n.trFor(root.pluginId, "Quick Actions")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }
            ToggleSetting {
                settingKey: "showWorkAction"
                label: I18n.trFor(root.pluginId, "Work")
                description: I18n.trFor(root.pluginId, "Show the work quick action")
                defaultValue: true
            }
            ToggleSetting {
                settingKey: "showShortBreakAction"
                label: I18n.trFor(root.pluginId, "Short break")
                description: I18n.trFor(root.pluginId, "Show the short break quick action")
                defaultValue: true
            }
            ToggleSetting {
                settingKey: "showLongBreakAction"
                label: I18n.trFor(root.pluginId, "Long break")
                description: I18n.trFor(root.pluginId, "Show the optional long break quick action")
                defaultValue: false
            }
            ToggleSetting {
                settingKey: "showDashboardAction"
                label: I18n.trFor(root.pluginId, "Dashboard")
                description: I18n.trFor(root.pluginId, "Show the dashboard quick action")
                defaultValue: true
            }
        }
    }

    StyledRect {
        width: parent.width
        height: behaviorColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: behaviorColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor(root.pluginId, "Behavior")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "showStopwatch"
                label: I18n.trFor(root.pluginId, "Show Stopwatch")
                description: I18n.trFor(root.pluginId, "Show Stopwatch in the timer menu")
                defaultValue: true
            }

            StringSetting {
                settingKey: "dailyGoalMinutes"
                label: I18n.trFor(root.pluginId, "Daily goal (minutes)")
                description: I18n.trFor(root.pluginId, "Daily focus target for the dashboard. Set 0 to disable. Default: 60.")
                placeholder: "60"
                defaultValue: "60"
            }

            StringSetting {
                objectName: "streakMinimumMinutesSetting"
                settingKey: "streakMinimumMinutes"
                label: I18n.trFor(root.pluginId, "Minimum time for a streak (minutes)")
                description: I18n.trFor(root.pluginId, "Minimum total recorded work per day to count toward a streak. Enter 1–1440 whole minutes. Default: 1.")
                placeholder: "1"
                defaultValue: "1"
            }

            ToggleSetting {
                settingKey: "autoStartBreaks"
                label: I18n.trFor(root.pluginId, "Auto-start breaks")
                description: I18n.trFor(root.pluginId, "Start the short break when work finishes")
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "autoStartPomodoros"
                label: I18n.trFor(root.pluginId, "Auto-start work")
                description: I18n.trFor(root.pluginId, "Start a work session when the break finishes")
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "autoSetDND"
                label: I18n.trFor(root.pluginId, "Do Not Disturb during work")
                description: I18n.trFor(root.pluginId, "Enable Do Not Disturb during work sessions")
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "showBarText"
                label: I18n.trFor(root.pluginId, "Show timer text in the bar")
                description: I18n.trFor(root.pluginId, "Show the remaining time next to the icon")
                defaultValue: true
            }

            ToggleSetting {
                settingKey: "playCompletionSound"
                label: I18n.trFor(root.pluginId, "Completion sound")
                description: I18n.trFor(root.pluginId, "Play a sound when work or a break finishes")
                defaultValue: true
            }
        }
    }

    StyledRect {
        width: parent.width
        height: infoColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DIcon {
                    name: "info"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.trFor(root.pluginId, "How it works")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: I18n.trFor(root.pluginId, "Alternate work sessions and short breaks.\n\n• Pause suspends the timer without saving.\n• Record session saves whole minutes and prepares a new work timer.\n• Reset discards the current session.\n• Completed work sessions are saved automatically.\n\nA streak requires the minimum daily recorded work time configured above. The dashboard keeps your work minutes and groups them by day, month or year.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
