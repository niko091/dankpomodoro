import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const read = (file: string): string => readFileSync(new URL("../" + file, import.meta.url), "utf8");
const catalog: Record<string, Record<string, string>> = JSON.parse(read("translations/it.json"));
const files = ["DankPomodoroWidget.qml", "DankPomodoroSettings.qml", "MinuteChart.qml", "PomodoroPresetsSetting.qml", "PomodoroDashboard.qml", "FocusChart.qml", "DashboardStatCard.qml"];

test("Italian catalog covers every DMS translation call and preserves placeholders", () => {
    const terms = new Set<string>();
    for (const file of files) {
        for (const match of read(file).matchAll(/I18n\.trFor\(([^,]+),/g))
            assert.equal(match[1], '"dankPomodoroTimerPlusPlus"', file + ": translation extraction requires a literal plugin id");
        for (const match of read(file).matchAll(/I18n\.trFor\([^,]+,\s*("(?:\\.|[^"\\])*")/g))
            terms.add(JSON.parse(match[1]));
    }
    assert.ok(terms.size > 60);
    for (const term of terms) {
        const translated = catalog[term]?.[term];
        assert.equal(typeof translated, "string", "Missing Italian translation: " + term);
        assert.ok(translated.length > 0, "Empty Italian translation: " + term);
        assert.deepEqual(
            (translated.match(/%\d+/g) || []).sort(),
            (term.match(/%\d+/g) || []).sort(),
            "Translation changes placeholders: " + term,
        );
    }
});

test("visible UI literals use DMS translation calls; metadata defaults to English", () => {
    for (const file of files) {
        for (const match of read(file).matchAll(/(?:text|label|description|tooltipText|Accessible\.name|headerText|detailsText):\s*("(?:\\.|[^"\\])*")/g)) {
            const text: string = JSON.parse(match[1]);
            assert.ok(!/[a-zA-ZÀ-ÿ]/.test(text) || text === "Pomodoro Timer++", file + ": untranslated UI text: " + text);
        }
    }
    const manifest = JSON.parse(read("plugin.json"));
    assert.equal(manifest.description, "Pomodoro timer with configurable presets, work minutes, streaks and history dashboard");
    assert.equal(manifest.type, "widget");
    assert.ok(manifest.permissions.includes("process"), "Completion notifications execute the dms command");
});
