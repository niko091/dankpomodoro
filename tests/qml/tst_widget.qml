import QtQuick
import QtTest
import Quickshell
import qs.Common
import qs.Services
import "../../" as App
import "../../Pomodoro.js" as Logic

TestCase {
    id: testCase
    name: "PomodoroWidget"
    width: 1200
    height: 1080
    visible: true
    when: windowShown
    property var widget
    property var popup

    Component {
        id: widgetFactory
        App.DankPomodoroWidget {
            pluginId: "dankPomodoroTimerPlusPlus"
            pluginService: PluginService
        }
    }
    Component {
        id: settingsFactory
        App.DankPomodoroSettings { width: 440; pluginService: PluginService }
    }

    function init() {
        failOnWarning(/.*/);
        I18n.pluginTranslations = {};
        Quickshell.commands = [];
        PluginService.globalVars = {};
        PluginService.states = {};
        PluginService.settings = {};
        widget = createTemporaryObject(widgetFactory, testCase);
        verify(widget !== null);
        popup = createTemporaryObject(widget.popoutContent, testCase, { width: 440 });
        verify(popup !== null);
        wait(10);
    }

    function test_initialAndDashboard() {
        compare(widget.timer.remainingMs, 1500000);
        compare(widget.todayMinutes, 0);
        compare(widget.streakDays, 0);
        widget.dashboardVisible = true;
        wait(10);
        compare(widget.dashboardWindow.windowTitle, "Pomodoro Dashboard");
        compare(widget.dashboardData.length, 1);
        widget.grouping = "months";
        compare(widget.dashboardData.length, 1);
        widget.grouping = "years";
        compare(widget.totalMinutes, 0);
        verify(createTemporaryObject(settingsFactory, testCase) !== null);
    }

    function test_hostControlsBarAndDockSizing() {
        const horizontal = createTemporaryObject(widget.horizontalBarPill, testCase);
        const vertical = createTemporaryObject(widget.verticalBarPill, testCase);
        for (const pill of [horizontal, vertical]) {
            verify(pill !== null);
            compare(findChild(pill, "barTimerIcon").size, 24);
            compare(findChild(pill, "barTimerText").font.pixelSize, 14);
        }
        widget.iconSize = 32;
        widget.textSize = 18;
        for (const pill of [horizontal, vertical]) {
            compare(findChild(pill, "barTimerIcon").size, 32);
            compare(findChild(pill, "barTimerText").font.pixelSize, 18);
        }
    }

    function test_weeklyCardsAlignmentAndComparison() {
        widget.today = new Date(2026, 10, 7, 12);
        widget.history = { "2026-10-26": 100, "2026-11-02": 150 };
        widget.sessionStats = Logic.Pomodoro.cleanSessionStats({ sessionsByDay: { "2026-10-26": 2, "2026-11-02": 3 } });
        widget.dashboardVisible = true;
        wait(10);
        for (const name of ["weeklyMinutesCard", "weeklySessionsCard"]) {
            const card = findChild(widget.dashboardWindow, name);
            verify(card !== null);
            const value = findChild(card, "statValue");
            const icon = findChild(card, "statIcon");
            const title = findChild(card, "statTitle");
            const comparison = findChild(card, "statComparison");
            const textTop = value.mapToItem(card, 0, 0).y;
            const textBottom = title.mapToItem(card, 0, title.height).y;
            compare(textTop, icon.y);
            compare(comparison.text, "+50% vs last week");
            verify(comparison.mapToItem(card, 0, 0).y >= textBottom);
        }
        const minutesCard = findChild(widget.dashboardWindow, "weeklyMinutesCard");
        const valueY = findChild(minutesCard, "statValue").mapToItem(minutesCard, 0, 0).y;
        const titleY = findChild(minutesCard, "statTitle").mapToItem(minutesCard, 0, 0).y;
        for (const name of ["weeklySessionsCard", "averageSessionCard", "monthlyGoalsCard"]) {
            const card = findChild(widget.dashboardWindow, name);
            compare(findChild(card, "statValue").mapToItem(card, 0, 0).y, valueY);
            compare(findChild(card, "statTitle").mapToItem(card, 0, 0).y, titleY);
        }
        widget.history = { "2026-11-02": 150 };
        const minutesComparison = findChild(findChild(widget.dashboardWindow, "weeklyMinutesCard"), "statComparison");
        compare(minutesComparison.visible, true);
        compare(minutesComparison.text, "— vs last week");
        widget.history = {};
        compare(minutesComparison.text, "0% vs last week");
    }

    function test_streakMinimumSetting() {
        widget.today = new Date(2026, 10, 7, 12);
        widget.history = { "2026-11-05": 25, "2026-11-06": 30, "2026-11-07": 10 };
        compare(widget.streakMinimumMinutes, 1);
        compare(widget.streakDays, 3);
        const settings = createTemporaryObject(settingsFactory, testCase);
        const field = findChild(settings, "streakMinimumMinutesSetting");
        verify(field !== null);
        compare(field.settingKey, "streakMinimumMinutes");
        compare(field.defaultValue, "1");
        settings.saveValue(field.settingKey, "25");
        compare(widget.streakMinimumMinutes, 25);
        compare(widget.streakDays, 2);
        compare(widget.dashboardWindow.summary.streakDays, 2);
        const reopened = createTemporaryObject(widgetFactory, testCase);
        compare(reopened.streakMinimumMinutes, 25);
        settings.saveValue(field.settingKey, "40");
        compare(widget.streakDays, 0);
        compare(widget.dashboardWindow.summary.streakDays, 0);
        settings.saveValue(field.settingKey, "bad");
        compare(widget.streakMinimumMinutes, 1);
        compare(widget.streakDays, 3);
    }

    function test_recordPauseResetAndReload() {
        const now = Date.now();
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("work", 25), now - 760000));
        widget.registerSession();
        // A recent session can span local midnight; fixed-date tests cover its daily allocation.
        compare(widget.totalMinutes, 12);
        compare(widget.totalMinutes, 12);
        verify(widget.streakDays >= 1 && widget.streakDays <= 2);
        compare(widget.timer.running, false);
        compare(widget.timer.remainingMs, 1500000);
        widget.registerSession();
        compare(widget.totalMinutes, 12);

        widget.toggleTimer();
        compare(widget.timer.running, true);
        widget.toggleTimer();
        compare(widget.timer.running, false);
        widget.resetTimer();
        compare(widget.totalMinutes, 12);

        const other = createTemporaryObject(widgetFactory, testCase);
        compare(other.totalMinutes, 12);
        compare(other.timer.remainingMs, 1500000);
        other.selectMode("shortBreak", false);
        other.registerSession();
        compare(other.totalMinutes, 12);
    }

    function test_autoCompleteAndDND() {
        widget.pluginData = { autoSetDND: true };
        widget.toggleTimer();
        compare(SessionData.doNotDisturb, true);
        widget.toggleTimer();
        compare(SessionData.doNotDisturb, false);
        const now = Date.now();
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("work", 25), now - 1500000));
        widget.timerComplete();
        compare(widget.totalMinutes, 25);
        compare(widget.timer.mode, "shortBreak");
        compare(widget.timer.running, false);
        widget.timerComplete();
        compare(widget.totalMinutes, 25);
        compare(widget.timer.mode, "work");
    }

    function test_historySyncAndViews() {
        const second = createTemporaryObject(widgetFactory, testCase);
        const key = Logic.Pomodoro.dateKey(new Date());
        const history = {};
        history[key] = 42;
        history["2020-01-01"] = 8;
        PluginService.savePluginState(widget.pluginId, "minutesByDay", history);
        compare(widget.todayMinutes, 42);
        compare(second.totalMinutes, 50);
        compare(widget.canGoBack, false);
        widget.chartPage = 2;
        widget.grouping = "years";
        compare(widget.chartPage, 0);
        verify(createTemporaryObject(widget.horizontalBarPill, testCase) !== null);
        verify(createTemporaryObject(widget.verticalBarPill, testCase) !== null);
    }

    function test_modeChangePreservesUnsavedWork() {
        const now = Date.now();
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("work", 25), now - 120000));
        compare(widget.selectMode("shortBreak", false), false);
        compare(widget.timer.mode, "work");
        compare(widget.totalMinutes, 0);
        widget.registerSession();
        compare(widget.totalMinutes, 2);
        compare(widget.selectMode("shortBreak", false), true);
        compare(widget.timer.mode, "shortBreak");
    }

    function test_presetIconSelectionAndPersistence() {
        const button = findChild(popup, "presetSelectorButton");
        const menu = findChild(popup, "presetMenu");
        verify(button !== null);
        verify(menu !== null);
        const contentHeight = popup.height;
        mouseClick(button);
        compare(menu.menuOpen, true);
        compare(menu.currentValue, "25/5");
        compare(popup.height, contentHeight);
        waitForRendering(popup);
        const choice = findChild(menu.menuContent, "preset-50/10");
        verify(choice !== null);
        mouseClick(choice);
        compare(menu.menuOpen, false);
        compare(widget.activePreset.key, "50/10");
        compare(widget.timer.remainingMs, 50 * 60000);
        compare(widget.shortBreakDuration, 10);
        compare(PluginService.loadPluginState(widget.pluginId, "activePreset", ""), "50/10");
        widget.dashboardVisible = true;
        widget.dashboardWindow.close();
        mouseClick(button);
        compare(menu.menuOpen, true);
        compare(menu.currentValue, "50/10");
        keyClick(Qt.Key_Escape);
        compare(menu.menuOpen, false);
        compare(widget.activePreset.key, "50/10");
        mouseClick(button);
        compare(menu.menuOpen, true);
        mouseClick(testCase, 10, 800);
        compare(menu.menuOpen, false);
        compare(widget.activePreset.key, "50/10");
        const second = createTemporaryObject(widgetFactory, testCase);
        compare(second.activePreset.key, "50/10");
        compare(second.workDuration, 50);
        compare(second.timer.remainingMs, 50 * 60000);
        second.selectPreset("25/5");
        compare(widget.activePreset.key, "25/5");
        compare(widget.timer.remainingMs, 25 * 60000);
    }

    function test_customPresetSettingsAndRemoval() {
        widget.pluginData = { timerPresets: "40/8, 90/15" };
        compare(widget.timerPresets.length, 2);
        compare(widget.activePreset.key, "40/8");
        compare(widget.timer.remainingMs, 40 * 60000);
        widget.selectPreset("90/15");
        compare(widget.workDuration, 90);
        compare(widget.shortBreakDuration, 15);
        widget.selectPreset("invalid");
        compare(widget.activePreset.key, "90/15");
        widget.pluginData = { timerPresets: "40/8" };
        compare(widget.activePreset.key, "40/8");
        widget.pluginData = { timerPresets: "invalid" };
        compare(widget.activePreset.key, "25/5");
    }

    function test_presetChangeKeepsActiveWork() {
        const now = Date.now();
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("work", 25), now - 10 * 60000));
        widget.selectPreset("50/10");
        verify(widget.timer.running);
        verify(Math.abs(widget.timer.remainingMs - 40 * 60000) < 1000);
        widget.registerSession();
        compare(widget.totalMinutes, 10);
        compare(widget.timer.remainingMs, 50 * 60000);
        widget.selectMode("shortBreak", false);
        compare(widget.timer.remainingMs, 10 * 60000);
        widget.selectPreset("25/5");
        compare(widget.timer.remainingMs, 5 * 60000);
    }

    function test_englishDefaultAndItalianLocaleSwitch() {
        widget.dashboardVisible = true;
        widget.resetTimer();
        compare(widget.dashboardWindow.windowTitle, "Pomodoro Dashboard");
        compare(widget.sessionMessage, "Session reset");
        verify(popup.detailsText.indexOf("min today") >= 0);
        verify(popup.detailsText.indexOf("Streak: 0 days") >= 0);
        const settings = createTemporaryObject(settingsFactory, testCase);
        compare(findChild(settings, "settingsTitle").text, "Pomodoro++ Settings");
        const chart = findChild(widget.dashboardWindow, "dashboardChart");
        compare(chart.months[0], "Jan");

        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../../translations/it.json"), false);
        request.send();
        const catalog = JSON.parse(request.responseText);
        I18n.registerPluginTranslations(widget.pluginId, catalog);
        compare(widget.dashboardWindow.windowTitle, "Dashboard Pomodoro");
        compare(widget.sessionMessage, "Sessione azzerata");
        verify(popup.detailsText.indexOf("min oggi") >= 0);
        verify(popup.detailsText.indexOf("Streak: 0 giorni") >= 0);
        compare(findChild(settings, "settingsTitle").text, "Impostazioni Pomodoro++");
        compare(findChild(popup, "presetSelectorButton").tooltipText, "Scegli timer Pomodoro");
        compare(chart.months[0], "gen");

        const now = Date.now();
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("work", 25), now - 60000));
        widget.registerSession();
        compare(widget.sessionMessage, "Sessione registrata: 1 min");
        verify(popup.detailsText.indexOf("Streak: 1 giorno") >= 0);
        I18n.unregisterPluginTranslations(widget.pluginId);
        compare(widget.sessionMessage, "Session recorded: 1 min");
        compare(widget.dashboardWindow.windowTitle, "Pomodoro Dashboard");
        verify(popup.detailsText.indexOf("Streak: 1 day") >= 0);
        compare(chart.months[0], "Jan");

        widget.timerComplete();
        compare(Quickshell.commands[0][4], "Pomodoro complete");
        I18n.registerPluginTranslations(widget.pluginId, catalog);
        widget.timerComplete();
        compare(Quickshell.commands[1][4], "Pausa terminata");
    }

    function test_configurableQuickActionsAndLongBreak() {
        compare(widget.quickActionKeys.join(","), "work,shortBreak,dashboard");
        verify(findChild(popup, "quickAction-longBreak") === null);
        widget.pluginData = {
            showWorkAction: false,
            showDashboardAction: false,
            showLongBreakAction: true,
            longBreakDuration: "20",
            autoSetDND: true
        };
        waitForRendering(popup);
        compare(widget.quickActionKeys.join(","), "shortBreak,longBreak");
        const action = findChild(popup, "quickAction-longBreak");
        verify(action !== null);
        compare(action.text, "Long break");
        compare(action.iconName, "weekend");
        mouseClick(action);
        compare(widget.timer.mode, "longBreak");
        compare(widget.timer.remainingMs, 20 * 60000);
        compare(widget.timer.running, false);
        compare(findChild(popup, "recordSessionButton").enabled, false);
        widget.toggleTimer();
        compare(SessionData.doNotDisturb, false);
        widget.resetTimer();
        compare(widget.timer.mode, "longBreak");
        compare(widget.timer.remainingMs, 20 * 60000);
        widget.timerComplete();
        compare(widget.totalMinutes, 0);
        compare(widget.timer.mode, "work");

        widget.pluginData = { showWorkAction: false, showShortBreakAction: false, showDashboardAction: false };
        compare(widget.quickActionKeys.length, 0);
    }

    function test_stopwatchMenuPauseRecordAndReset() {
        const button = findChild(popup, "presetSelectorButton");
        const menu = findChild(popup, "presetMenu");
        mouseClick(button);
        waitForRendering(popup);
        const choice = findChild(menu.menuContent, "preset-stopwatch");
        verify(choice !== null);
        compare(choice.text, "Stopwatch");
        mouseClick(choice);
        compare(menu.menuOpen, false);
        compare(widget.timer.mode, "stopwatch");
        compare(widget.displayMs, 0);
        compare(widget.timer.running, false);
        compare(PluginService.loadPluginState(widget.pluginId, "activePreset", ""), "stopwatch");
        widget.pluginData = { autoSetDND: true };
        widget.toggleTimer();
        wait(300);
        verify(widget.timer.running);
        verify(widget.timer.elapsedMs > 0);
        compare(SessionData.doNotDisturb, true);
        compare(Quickshell.commands.length, 0);
        const now = Date.now();
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("stopwatch", 0), now - 760000));
        widget.toggleTimer();
        compare(widget.timer.running, false);
        compare(SessionData.doNotDisturb, false);
        compare(Logic.Pomodoro.formatTime(widget.displayMs), "12:40");
        const record = findChild(popup, "recordSessionButton");
        verify(record.enabled);
        mouseClick(record);
        compare(widget.totalMinutes, 12);
        verify(widget.streakDays >= 1 && widget.streakDays <= 2);
        compare(widget.timer.mode, "stopwatch");
        compare(widget.timer.elapsedMs, 0);
        compare(widget.timer.running, false);
        widget.registerSession();
        compare(widget.totalMinutes, 12);
        const second = createTemporaryObject(widgetFactory, testCase);
        compare(second.timer.mode, "stopwatch");
        compare(second.selectedTimerKey, "stopwatch");
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("stopwatch", 0), now - 180000));
        widget.resetTimer();
        compare(widget.timer.elapsedMs, 0);
        compare(widget.totalMinutes, 12);
        widget.selectPreset("25/5");
        compare(widget.timer.mode, "work");
        compare(widget.timer.remainingMs, 25 * 60000);
        widget.pluginData = { showStopwatch: false };
        verify(menu.optionValues.indexOf("stopwatch") < 0);
        widget.selectPreset("stopwatch");
        compare(widget.timer.mode, "work");
        widget.pluginData = { showStopwatch: true };
        verify(menu.optionValues.indexOf("stopwatch") >= 0);
        widget.selectPreset("stopwatch");
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("stopwatch", 0), Date.now() - 120000));
        widget.pluginData = { showStopwatch: false };
        compare(widget.timer.mode, "work");
        verify(widget.timer.elapsedMs >= 120000);
        widget.registerSession();
        compare(widget.totalMinutes, 14);
    }

    function test_threeFieldProfileEditorAddsEditsAndPersists() {
        const settings = createTemporaryObject(settingsFactory, testCase);
        const editor = findChild(settings, "timerProfilesEditor");
        verify(editor !== null);
        compare(editor.profiles.length, 2);
        compare(findChild(editor, "profile-work-0").text, "25");
        compare(findChild(editor, "profile-short-0").text, "5");
        compare(findChild(editor, "profile-long-0").text, "15");
        waitForRendering(settings);
        mouseClick(findChild(editor, "addTimerButton"));
        compare(editor.profiles.length, 3);
        waitForRendering(settings);
        let input = findChild(editor, "profile-work-2");
        input.text = "45";
        input.editingFinished();
        input = findChild(editor, "profile-short-2");
        input.text = "9";
        input.editingFinished();
        input = findChild(editor, "profile-long-2");
        input.text = "22";
        input.editingFinished();
        compare(editor.profiles[2].workMinutes, 45);
        compare(editor.profiles[2].breakMinutes, 9);
        compare(editor.profiles[2].longBreakMinutes, 22);
        compare(widget.timerPresets.length, 3);
        widget.selectPreset("45/9/22");
        compare(widget.workDuration, 45);
        compare(widget.shortBreakDuration, 9);
        compare(widget.longBreakDuration, 22);
        widget.selectMode("longBreak", false);
        compare(widget.timer.remainingMs, 22 * 60000);
        const reopened = createTemporaryObject(settingsFactory, testCase);
        const restored = findChild(reopened, "timerProfilesEditor");
        compare(restored.profiles.length, 3);
        compare(restored.profiles[2].longBreakMinutes, 22);
        editor.removeProfile(2);
        compare(editor.profiles.length, 2);
        editor.removeProfile(1);
        editor.removeProfile(0);
        compare(editor.profiles.length, 1);
    }

    function test_dashboardWindowKeepsTimerRunningAndTracksNewStatistics() {
        const key = Logic.Pomodoro.dateKey(new Date());
        const existing = {};
        existing[key] = 60;
        PluginService.savePluginState(widget.pluginId, "minutesByDay", existing);
        widget.toggleTimer();
        widget.openDashboard();
        const dashboard = widget.dashboardWindow;
        verify(dashboard.shouldBeVisible);
        verify(widget.popoutClosed);
        compare(dashboard.positioning, "center");
        compare(dashboard.modalWidth, 1100);
        tryVerify(() => dashboard.preferredContentHeight > 320);
        compare(dashboard.modalHeight, dashboard.preferredContentHeight);
        verify(dashboard.modalHeight < 940);
        verify(widget.timer.running);
        compare(dashboard.summary.totalMinutes, 60);
        compare(dashboard.summary.totalSessions, 0);
        const now = Date.now();
        PluginService.setGlobalVar(widget.pluginId, "timer",
            Logic.Pomodoro.toggle(Logic.Pomodoro.createTimer("work", 25), now - 760000));
        widget.registerSession();
        compare(dashboard.summary.totalMinutes, 72);
        compare(dashboard.summary.totalSessions, 1);
        compare(dashboard.summary.averageMinutes, 12);
        compare(dashboard.sessionStats.trackingSince, key);
        verify(PluginService.loadPluginState(widget.pluginId, "sessionStats", {}).sessionsByDay[key] === 1);
        widget.registerSession();
        compare(dashboard.summary.totalSessions, 1);
        waitForRendering(dashboard.contentLoader.item);
        mouseClick(findChild(dashboard, "dashboard-group-weeks"));
        compare(dashboard.grouping, "weeks");
        verify(dashboard.chartData.length >= 1);
        compare(dashboard.canGoBack, false);
        mouseClick(findChild(dashboard, "closeDashboardButton"));
        compare(dashboard.shouldBeVisible, false);
    }
}
