import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
mkdirSync(new URL("../dist/", import.meta.url), { recursive: true });
const archive = "dist/DankPomodoroTimerPlusPlus.tar.gz";
execFileSync("tar", [
    "-czf", archive,
    "plugin.json",
    "DankPomodoroWidget.qml",
    "DankPomodoroSettings.qml",
    "MinuteChart.qml",
    "PomodoroIconButton.qml",
    "PomodoroPresetsSetting.qml",
    "PomodoroDashboard.qml",
    "DashboardStatCard.qml",
    "FocusChart.qml",
    "Pomodoro.js",
    "translations",
    "LICENSE",
    "README.md",
], { cwd: root, stdio: "inherit" });
console.log(archive);
