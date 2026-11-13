import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import qs.DCommon.Widgets
import "Pomodoro.js" as Logic

PluginComponent {
    id: root
    layerNamespacePlugin: "pomodoro-timer-plus-plus"
    popoutWidth: 400
    readonly property var timerPresets: Logic.Pomodoro.parsePresets(pluginData.timerProfiles ?? pluginData.timerPresets, pluginData.longBreakDuration)
    property string selectedPresetKey: ""
    readonly property var activePreset: Logic.Pomodoro.activePreset(timerPresets, selectedPresetKey)
    readonly property bool showStopwatch: pluginData.showStopwatch ?? true
    readonly property string workMode: showStopwatch && selectedPresetKey === "stopwatch" ? "stopwatch" : "work"
    readonly property string selectedTimerKey: workMode === "stopwatch" ? "stopwatch" : activePreset.key
    readonly property string selectedTimerLabel: workMode === "stopwatch" ? I18n.trFor("dankPomodoroTimerPlusPlus", "Stopwatch") : activePreset.key
    readonly property int workDuration: activePreset.workMinutes
    readonly property int shortBreakDuration: activePreset.breakMinutes
    readonly property int longBreakDuration: activePreset.longBreakMinutes
    readonly property var quickActionKeys: Logic.Pomodoro.quickActions(pluginData)
    property bool ready: false
    readonly property bool autoStartBreaks: pluginData.autoStartBreaks ?? false
    readonly property bool autoStartPomodoros: pluginData.autoStartPomodoros ?? false
    readonly property bool autoSetDND: pluginData.autoSetDND ?? false
    readonly property bool showBarText: pluginData.showBarText ?? true
    readonly property bool playCompletionSound: pluginData.playCompletionSound ?? true
    readonly property var timer: globalTimer.value
    readonly property bool isWorkSession: Logic.Pomodoro.isWorkMode(timer.mode)
    readonly property bool hasUnrecordedWork: Logic.Pomodoro.hasUnrecordedWork(timer)
    readonly property real displayMs: Logic.Pomodoro.displayMs(timer)
    property var history: ({})
    property var sessionStats: Logic.Pomodoro.cleanSessionStats({})
    readonly property int dailyGoalMinutes: Logic.Pomodoro.dailyGoal(pluginData.dailyGoalMinutes)
    readonly property int streakMinimumMinutes: Logic.Pomodoro.validDuration(pluginData.streakMinimumMinutes, 1)
    property var today: new Date()
    property alias dashboardVisible: dashboard.shouldBeVisible
    property alias grouping: dashboard.grouping
    property alias chartPage: dashboard.chartPage
    readonly property alias dashboardWindow: dashboard
    property string sessionMessageKind: ""
    property int recordedMinutes: 0
    readonly property string sessionMessage: {
        switch (sessionMessageKind) {
        case "switchMode":
            return I18n.trFor("dankPomodoroTimerPlusPlus", "Record or reset the session before switching modes.");
        case "reset":
            return I18n.trFor("dankPomodoroTimerPlusPlus", "Session reset");
        case "saved":
            return I18n.trFor("dankPomodoroTimerPlusPlus", "Session recorded: %1 min").arg(recordedMinutes);
        case "tooShort":
            return I18n.trFor("dankPomodoroTimerPlusPlus", "Session shorter than one minute: 0 min saved");
        default:
            return "";
        }
    }
    property string instanceId: Math.random().toString(36).substring(2)
    readonly property int todayMinutes: history[Logic.Pomodoro.dateKey(today)] || 0
    readonly property int streakDays: Logic.Pomodoro.streak(history, today, streakMinimumMinutes)
    readonly property int totalMinutes: Logic.Pomodoro.totalMinutes(history)
    readonly property var last7DaysData: Logic.Pomodoro.chart(history, today, "days", 0, 7)
    readonly property var dashboardData: dashboard.chartData
    readonly property bool canGoBack: dashboard.canGoBack

    onPluginServiceChanged: loadHistory()
    Component.onCompleted: {
        loadHistory();
        ready = true;
        if (isWorkSession)
            applyWorkSelection();
        else
            updateDuration(root.timer.mode, durationForMode(root.timer.mode));
    }
    onWorkDurationChanged: applyWorkSelection()
    onWorkModeChanged: applyWorkSelection()
    onShortBreakDurationChanged: updateDuration("shortBreak", shortBreakDuration)
    onLongBreakDurationChanged: updateDuration("longBreak", longBreakDuration)

    function durationForMode(mode) {
        return Logic.Pomodoro.durationForMode(mode, activePreset, longBreakDuration);
    }

    function loadHistory() {
        if (pluginService) {
            history = Logic.Pomodoro.cleanHistory(pluginService.loadPluginState(root.pluginId, "minutesByDay", {}));
            sessionStats = Logic.Pomodoro.cleanSessionStats(pluginService.loadPluginState(root.pluginId, "sessionStats", {}));
            selectedPresetKey = pluginService.loadPluginState(root.pluginId, "activePreset", "");
        }
    }

    function selectPreset(key) {
        if (key === "stopwatch" && !root.showStopwatch)
            return;
        if (key !== "stopwatch" && !root.timerPresets.some(preset => preset.key === key))
            return;
        if (pluginService)
            pluginService.savePluginState(root.pluginId, "activePreset", key);
        else
            selectedPresetKey = key;
        if (key === "stopwatch" && !root.isWorkSession)
            selectMode("stopwatch", false);
    }

    function applyWorkSelection() {
        if (!ready || !globalTimer || !root.timer || !root.isWorkSession)
            return;
        globalTimer.set(Logic.Pomodoro.changeWorkMode(root.timer, workMode, workDuration, Date.now()));
        if (root.timer.mode === "work" && root.timer.running && root.timer.remainingMs <= 0)
            timerComplete();
    }

    Connections {
        target: root.pluginService
        function onPluginStateChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                root.loadHistory();
        }
    }

    PluginGlobalVar {
        id: globalTimer
        varName: "timer"
        defaultValue: Logic.Pomodoro.createTimer("work", root.workDuration)
    }
    PluginGlobalVar {
        id: globalTimerOwnerId
        varName: "timerOwnerId"
        defaultValue: ""
    }

    Timer {
        objectName: "sessionTimer"
        interval: 250
        repeat: true
        running: root.timer.running && globalTimerOwnerId.value === root.instanceId
        onTriggered: {
            globalTimer.set(Logic.Pomodoro.tick(root.timer, Date.now()));
            if (root.timer.mode !== "stopwatch" && root.timer.remainingMs <= 0)
                root.timerComplete();
        }
    }

    Timer {
        objectName: "housekeepingTimer"
        interval: root.timer.running ? 1000 : 60000
        repeat: true
        triggeredOnStart: true
        running: root.surfaceLive || root.interactionActive || root.dashboardVisible || root.timer.running
        onTriggered: {
            const now = new Date();
            if (Logic.Pomodoro.dateKey(now) !== Logic.Pomodoro.dateKey(root.today))
                root.today = now;
            if (root.timer.running && globalTimerOwnerId.value === "")
                globalTimerOwnerId.set(root.instanceId);
        }
    }

    Component.onDestruction: {
        if (globalTimerOwnerId.value === root.instanceId)
            globalTimerOwnerId.set("");
    }

    function updateDuration(mode, minutes) {
        if (!ready || !globalTimer || !root.timer || root.timer.mode !== mode || mode === "stopwatch")
            return;
        globalTimer.set(Logic.Pomodoro.resize(root.timer, minutes, Date.now()));
        if (root.timer.running && root.timer.remainingMs <= 0)
            timerComplete();
    }

    function setDND(running) {
        if (autoSetDND)
            SessionData.setDoNotDisturb(running && root.isWorkSession);
    }

    function selectMode(mode, autoStart) {
        if (mode === "work")
            mode = root.workMode;
        const current = Logic.Pomodoro.tick(root.timer, Date.now());
        if (Logic.Pomodoro.hasUnrecordedWork(current)) {
            globalTimer.set(current);
            sessionMessageKind = "switchMode";
            return false;
        }
        setDND(false);
        globalTimer.set(Logic.Pomodoro.createTimer(mode, durationForMode(mode)));
        sessionMessageKind = "";
        if (autoStart)
            toggleTimer();
        return true;
    }

    function toggleTimer() {
        globalTimerOwnerId.set(root.instanceId);
        globalTimer.set(Logic.Pomodoro.toggle(root.timer, Date.now()));
        if (root.timer.mode !== "stopwatch" && root.timer.remainingMs <= 0) {
            timerComplete();
            return;
        }
        setDND(root.timer.running);
        sessionMessageKind = "";
    }

    function resetTimer() {
        setDND(false);
        globalTimer.set(Logic.Pomodoro.createTimer(root.timer.mode, durationForMode(root.timer.mode)));
        sessionMessageKind = "reset";
    }

    function saveWork() {
        if (!pluginService || !root.isWorkSession)
            return 0;
        loadHistory();
        const now = Date.now();
        const current = Logic.Pomodoro.tick(root.timer, now);
        const result = Logic.Pomodoro.finish(current, history, now, workDuration, root.workMode);
        const nextStats = Logic.Pomodoro.recordSessionStats(sessionStats, current, result.minutes, now);
        setDND(false);
        globalTimer.set(result.timer);
        pluginService.savePluginState(root.pluginId, "sessionStats", nextStats);
        pluginService.savePluginState(root.pluginId, "minutesByDay", result.history);
        today = new Date();
        return result.minutes;
    }

    function registerSession() {
        if (!pluginService || !root.isWorkSession)
            return I18n.trFor("dankPomodoroTimerPlusPlus", "No work session to record");
        const minutes = saveWork();
        recordedMinutes = minutes;
        sessionMessageKind = minutes > 0 ? "saved" : "tooShort";
        return sessionMessage;
    }

    function timerComplete() {
        if (root.timer.mode === "stopwatch")
            return;
        const wasWork = root.timer.mode === "work";
        if (wasWork) {
            if (!pluginService)
                return;
            saveWork();
        } else {
            setDND(false);
        }
        if (playCompletionSound && SettingsData.soundsEnabled)
            AudioService.playNormalNotificationSound();
        Quickshell.execDetached(["dms", "notify", "--urgency", "normal", wasWork ? I18n.trFor("dankPomodoroTimerPlusPlus", "Pomodoro complete") : I18n.trFor("dankPomodoroTimerPlusPlus", "Break complete"), wasWork ? I18n.trFor("dankPomodoroTimerPlusPlus", "Time for a short break.") : I18n.trFor("dankPomodoroTimerPlusPlus", "Ready for another session?")]);
        selectMode(wasWork ? "shortBreak" : "work", wasWork ? autoStartBreaks : autoStartPomodoros);
    }

    function getStateColor() {
        return root.isWorkSession ? Theme.primary : root.timer.mode === "longBreak" ? Theme.warning : Theme.info;
    }

    function openDashboard() {
        root.closePopout();
        dashboard.open();
    }

    PomodoroDashboard {
        id: dashboard
        objectName: "pomodoroDashboard"
        pluginId: root.pluginId
        history: root.history
        sessionStats: root.sessionStats
        today: root.today
        dailyGoalMinutes: root.dailyGoalMinutes
        streakMinimumMinutes: root.streakMinimumMinutes
        targetScreen: root.parentScreen
    }
    function getStateIcon() {
        return root.timer.mode === "stopwatch" ? "timer" : root.timer.mode === "work" ? "work" : root.timer.mode === "longBreak" ? "weekend" : "coffee";
    }

    IpcHandler {
        target: "pomodoroTimerPlusPlus"
        function resetTimer(): string {
            root.resetTimer();
            return "POMODORO_TIMER_RESET";
        }
        function toggleTimer(): string {
            root.toggleTimer();
            return root.timer.running ? I18n.trFor("dankPomodoroTimerPlusPlus", "Timer is running") : I18n.trFor("dankPomodoroTimerPlusPlus", "Timer is paused");
        }
        function registerSession(): string {
            return root.registerSession();
        }
        function startWork(): string {
            return root.selectMode("work", true) ? "POMODORO_WORK_STARTED" : root.sessionMessage;
        }
        function startShortBreak(): string {
            return root.selectMode("shortBreak", true) ? "POMODORO_SHORT_BREAK_STARTED" : root.sessionMessage;
        }
        function startLongBreak(): string {
            return root.selectMode("longBreak", true) ? "POMODORO_LONG_BREAK_STARTED" : root.sessionMessage;
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            DIcon {
                objectName: "barTimerIcon"
                name: root.getStateIcon()
                size: root.iconSize
                color: root.getStateColor()
                anchors.verticalCenter: parent.verticalCenter
            }

            NumericText {
                objectName: "barTimerText"
                text: Logic.Pomodoro.formatTime(root.displayMs)
                font.features: ({
                        "tnum": 1
                    })
                isMonospace: false
                font.pixelSize: root.textSize
                font.weight: Font.Medium
                color: Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showBarText
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.hairline(root.dpr)
            anchors.horizontalCenter: parent.horizontalCenter

            DIcon {
                objectName: "barTimerIcon"
                name: root.getStateIcon()
                size: root.iconSize
                color: root.getStateColor()
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Column {
                visible: root.showBarText
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0

                NumericText {
                    objectName: "barTimerText"
                    text: String(Math.floor(Math.ceil(root.displayMs / 1000) / 60)).padStart(2, "0")
                    font.features: ({
                            "tnum": 1
                        })
                    isMonospace: false
                    font.pixelSize: root.textSize
                    font.weight: Font.Medium
                    color: Theme.widgetTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                NumericText {
                    objectName: "barTimerText"
                    text: String(Math.ceil(root.displayMs / 1000) % 60).padStart(2, "0")
                    font.features: ({
                            "tnum": 1
                        })
                    isMonospace: false
                    font.pixelSize: root.textSize
                    font.weight: Font.Medium
                    color: Theme.widgetTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: timerPopout
            headerText: I18n.trFor("dankPomodoroTimerPlusPlus", "Pomodoro Timer++")
            detailsText: I18n.trFor("dankPomodoroTimerPlusPlus", "%1 min today").arg(root.todayMinutes) + "  •  " + (root.streakDays === 1 ? I18n.trFor("dankPomodoroTimerPlusPlus", "Streak: 1 day") : I18n.trFor("dankPomodoroTimerPlusPlus", "Streak: %1 days").arg(root.streakDays)) + "  •  " + root.selectedTimerLabel
            headerActions: Component {
                Item {
                    width: 32
                    height: 32
                    PomodoroIconButton {
                        id: presetButton
                        objectName: "presetSelectorButton"
                        controlSize: 32
                        iconSize: 20
                        iconName: "tune"
                        tooltipText: I18n.trFor("dankPomodoroTimerPlusPlus", "Choose Pomodoro timer")
                        Accessible.name: I18n.trFor("dankPomodoroTimerPlusPlus", "Choose Pomodoro timer")
                        onClicked: {
                            presetMenu.currentValue = root.selectedTimerKey;
                            presetMenu.openDropdownMenu();
                        }
                    }
                    DDropdown {
                        id: presetMenu
                        objectName: "presetMenu"
                        transientSurfaceTracker: timerPopout.parentPopout?.transientSurfaceTracker ?? null
                        showTrigger: false
                        popupAnchorItem: presetButton
                        focusReturnTarget: presetButton
                        alignPopupRight: true
                        dropdownWidth: 160
                        currentValue: root.selectedTimerKey
                        options: root.timerPresets.map(preset => preset.key).concat(root.showStopwatch ? [I18n.trFor("dankPomodoroTimerPlusPlus", "Stopwatch")] : [])
                        optionValues: root.timerPresets.map(preset => preset.key).concat(root.showStopwatch ? ["stopwatch"] : [])
                        onValueChanged: value => root.selectPreset(value)
                    }
                }
            }
            Column {
                width: parent.width
                spacing: Theme.spacingM
                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    Item {
                        width: parent.width
                        height: 180
                        Rectangle {
                            width: 180
                            height: 180
                            radius: 90
                            anchors.centerIn: parent
                            color: "transparent"
                            border.width: 8
                            border.color: Qt.alpha(root.getStateColor(), 0.2)
                            Canvas {
                                id: progressCanvas
                                width: parent.width - 16
                                height: parent.height - 16
                                anchors.centerIn: parent
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.lineWidth = 8;
                                    ctx.strokeStyle = root.getStateColor();
                                    ctx.beginPath();
                                    const progress = root.timer.mode === "stopwatch" ? 1 : root.timer.durationMs > 0 ? root.timer.remainingMs / root.timer.durationMs : 0;
                                    ctx.arc(width / 2, height / 2, (width - 8) / 2, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress, false);
                                    ctx.stroke();
                                }
                                Connections {
                                    target: root
                                    function onTimerChanged() {
                                        progressCanvas.requestPaint();
                                    }
                                }
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS
                                StyledText {
                                    text: Logic.Pomodoro.formatTime(root.displayMs)
                                    font.pixelSize: 36
                                    font.weight: Font.Bold
                                    color: root.getStateColor()
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                StyledText {
                                    text: root.timer.mode === "stopwatch" ? I18n.trFor("dankPomodoroTimerPlusPlus", "Stopwatch") : root.timer.mode === "work" ? I18n.trFor("dankPomodoroTimerPlusPlus", "Work") : root.timer.mode === "longBreak" ? I18n.trFor("dankPomodoroTimerPlusPlus", "Long break") : I18n.trFor("dankPomodoroTimerPlusPlus", "Short break")
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM
                        PomodoroIconButton {
                            objectName: "playPauseButton"
                            iconName: root.timer.running ? "pause" : "play_arrow"
                            iconSize: 32
                            textColor: root.getStateColor()
                            tooltipText: root.timer.running ? I18n.trFor("dankPomodoroTimerPlusPlus", "Pause") : I18n.trFor("dankPomodoroTimerPlusPlus", "Start")
                            onClicked: root.toggleTimer()
                        }
                        PomodoroIconButton {
                            objectName: "recordSessionButton"
                            iconName: "save"
                            tooltipText: I18n.trFor("dankPomodoroTimerPlusPlus", "Record session")
                            enabled: root.isWorkSession && !!root.pluginService && root.hasUnrecordedWork
                            onClicked: root.registerSession()
                        }
                        PomodoroIconButton {
                            objectName: "resetButton"
                            iconName: "refresh"
                            tooltipText: I18n.trFor("dankPomodoroTimerPlusPlus", "Reset")
                            onClicked: root.resetTimer()
                        }
                    }
                    StyledText {
                        width: parent.width
                        visible: root.sessionMessage.length > 0
                        text: root.sessionMessage
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
                Column {
                    id: quickActionSection
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.quickActionKeys.length > 0
                    StyledText {
                        text: I18n.trFor("dankPomodoroTimerPlusPlus", "Quick Actions")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    GridLayout {
                        id: quickActions
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(parent.width, implicitWidth)
                        columns: root.quickActionKeys.length > 3 ? 2 : Math.max(1, root.quickActionKeys.length)
                        columnSpacing: Theme.spacingS
                        rowSpacing: Theme.spacingS
                        Repeater {
                            model: root.quickActionKeys
                            DButton {
                                required property string modelData
                                objectName: "quickAction-" + modelData
                                Layout.alignment: Qt.AlignHCenter
                                Layout.minimumWidth: 0
                                maximumWidth: quickActionSection.width
                                horizontalPadding: Theme.spacingS
                                iconSize: 18
                                wrapText: false
                                buttonHeight: 32
                                variant: "filled"
                                text: {
                                    switch (modelData) {
                                    case "work":
                                        return I18n.trFor("dankPomodoroTimerPlusPlus", "Work");
                                    case "shortBreak":
                                        return I18n.trFor("dankPomodoroTimerPlusPlus", "Short break");
                                    case "longBreak":
                                        return I18n.trFor("dankPomodoroTimerPlusPlus", "Long break");
                                    default:
                                        return I18n.trFor("dankPomodoroTimerPlusPlus", "Dashboard");
                                    }
                                }
                                iconName: modelData === "work" ? "work" : modelData === "shortBreak" ? "coffee" : modelData === "longBreak" ? "weekend" : "bar_chart"
                                enabled: modelData === "dashboard" || !root.hasUnrecordedWork
                                onClicked: {
                                    if (modelData === "dashboard")
                                        root.openDashboard();
                                    else
                                        root.selectMode(modelData, false);
                                }
                            }
                        }
                    }
                }
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    StyledText {
                        text: I18n.trFor("dankPomodoroTimerPlusPlus", "Last 7 days")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }
                    MinuteChart {
                        objectName: "recentChart"
                        height: 80
                        width: parent.width
                        bars: root.last7DaysData
                    }
                }
            }
        }
    }
}
