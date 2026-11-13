import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

// Execute the actual compiled QML library, using the host Date for local time.
const context = vm.createContext({ Date });
vm.runInContext(readFileSync(new URL("../Pomodoro.js", import.meta.url), "utf8"), context);
const P = context.Pomodoro;
const at = (text: string): number => new Date(text).getTime();
const plain = (value: unknown) => JSON.parse(JSON.stringify(value));
const start = at("2026-11-07T10:00:00");

test("12:40 records 12 minutes, resets the timer, and cannot be recorded twice", () => {
    const timer = P.toggle(P.createTimer("work", 25), start);
    const first = P.finish(timer, {}, start + 760000, 25);
    assert.equal(first.minutes, 12);
    assert.deepEqual(plain(first.history), { "2026-11-07": 12 });
    assert.equal(first.timer.running, false);
    assert.equal(first.timer.remainingMs, 1500000);
    const second = P.finish(first.timer, first.history, start + 900000, 25);
    assert.equal(second.minutes, 0);
    assert.deepEqual(plain(second.history), plain(first.history));
});

test("several sessions add minutes rather than session counts; floor is per session", () => {
    let history = {};
    for (const ms of [760000, 1500000, 59000]) {
        const result = P.finish(P.toggle(P.createTimer("work", 25), start), history, start + ms, 25);
        history = result.history;
    }
    assert.deepEqual(plain(history), { "2026-11-07": 37 });
});

test("pause and resume exclude all paused time and retain subsecond work", () => {
    let timer = P.toggle(P.createTimer("work", 25), start);
    timer = P.toggle(timer, start + 60500);
    assert.equal(P.tick(timer, start + 3600000).remainingMs, 1439500);
    timer = P.toggle(timer, start + 3600000);
    const result = P.finish(timer, {}, start + 3659500, 25);
    assert.equal(result.minutes, 2);
});

test("completion caps elapsed time at the work duration after delayed ticks", () => {
    const timer = P.tick(P.toggle(P.createTimer("work", 25), start), start + 7200000);
    assert.equal(timer.remainingMs, 0);
    assert.equal(P.finish(timer, {}, start + 8000000, 25).minutes, 25);
});

test("breaks never contribute minutes", () => {
    const timer = P.toggle(P.createTimer("shortBreak", 5), start);
    const result = P.finish(timer, { "2026-11-06": 10 }, start + 300000, 25);
    assert.equal(result.minutes, 0);
    assert.deepEqual(plain(result.history), { "2026-11-06": 10 });
});

test("reset discards unrecorded work without changing saved history", () => {
    const saved = { "2026-11-07": 25 };
    let timer = P.tick(P.toggle(P.createTimer("work", 25), start), start + 760000);
    timer = P.createTimer(timer.mode, 25);
    assert.deepEqual(plain(P.finish(timer, saved, start + 1000000, 25).history), saved);
});

test("one saved minute qualifies, yesterday's streak remains until a missed day", () => {
    const history = { "2026-11-04": 1, "2026-11-05": 1, "2026-11-06": 1 };
    assert.equal(P.streak(history, new Date("2026-11-07T23:00:00")), 3);
    assert.equal(P.streak({ ...history, "2026-11-07": 1 }, new Date(start)), 4);
    assert.equal(P.streak(history, new Date("2026-11-08T00:00:00")), 0);
    assert.equal(P.streak({}, new Date(start)), 0);
});

test("streak uses the daily minimum, preserves yesterday until today qualifies, and breaks on short days", () => {
    const now = new Date("2026-11-07T12:00:00");
    const history = { "2026-11-03": 60, "2026-11-04": 24, "2026-11-05": 25, "2026-11-06": 30, "2026-11-07": 10 };
    assert.equal(P.streak(history, now, "25"), 2);
    assert.equal(P.streak({ ...history, "2026-11-07": 25 }, now, 25), 3);
    assert.equal(P.streak(history, now, 31), 0);
    assert.equal(P.streak({}, now, 25), 0);
    for (const invalid of [undefined, null, "", "bad", 0, -1, Infinity])
        assert.equal(P.streak(history, now, invalid), 5);
    assert.equal(P.streak({ "2026-11-07": 1440 }, now, 1440), 1);
});

test("work crossing midnight is attributed to the actual local dates", () => {
    const begin = at("2026-11-07T23:58:00");
    const result = P.finish(P.toggle(P.createTimer("work", 25), begin), {}, begin + 300000, 25);
    assert.deepEqual(plain(result.history), { "2026-11-07": 2, "2026-11-08": 3 });
    const fractional = P.recordSession({}, { "2026-11-07": 40000, "2026-11-08": 40000 });
    assert.equal(fractional.minutes, 1);
    assert.deepEqual(plain(fractional.history), { "2026-11-08": 1 });
});

test("DST and leap days preserve real elapsed minutes and streaks", () => {
    for (const date of ["2026-03-29", "2026-10-25"]) {
        const begin = at(date + "T00:00:00");
        const end = new Date(begin);
        end.setDate(end.getDate() + 1);
        const result = P.recordSession({}, P.addInterval({}, begin, end.getTime()));
        assert.equal(result.minutes, date.includes("03") ? 1380 : 1500);
    }
    assert.equal(P.streak({ "2024-02-28": 1, "2024-02-29": 1, "2024-03-01": 1 }, new Date("2024-03-01T12:00:00")), 3);
});

test("day/month/year charts sum minutes, include zero periods and page into old history", () => {
    const history = { "2024-03-02": 5, "2025-12-31": 10, "2026-10-15": 20, "2026-11-01": 30, "2026-11-07": 12 };
    const now = new Date(start);
    assert.equal(P.totalMinutes(history), 77);
    assert.equal(P.chart(history, now, "months", 0, 7).at(-1).minutes, 42);
    assert.equal(P.chart(history, now, "years", 0, 7).at(-1).minutes, 62);
    const days = P.chart(history, now, "days", 0, 7);
    assert.equal(days[0].minutes, 30);
    assert.equal(days[1].minutes, 0);
    assert.equal(days.at(-1).minutes, 12);
    assert.equal(P.hasEarlier(history, days, "days"), true);
    assert.equal(P.chart(history, now, "days", 1, 7).at(-1).key, "2026-10-31");
    const january = P.chart(history, new Date("2026-01-31T12:00:00"), "months", 0, 7);
    assert.deepEqual(plain(january.map((bar: { key: string }) => bar.key)), ["2025-07", "2025-08", "2025-09", "2025-10", "2025-11", "2025-12", "2026-01"]);
});

test("duration edits preserve elapsed work; invalid durations fall back", () => {
    const timer = P.resize(P.toggle(P.createTimer("work", 25), start), 30, start + 120000);
    assert.equal(timer.remainingMs, 28 * 60000);
    assert.equal(P.finish(timer, {}, start + 180000, 30).minutes, 3);
    for (const value of ["", "abc", 0, -1, null]) assert.equal(P.validDuration(value, 25), 25);
    assert.equal(P.validDuration("15", 25), 15);
    assert.equal(P.validDuration(99999, 25), 1440);
});

test("stored history survives reload and rejects malformed data", () => {
    assert.deepEqual(plain(P.cleanHistory(JSON.parse('{"2026-11-07":12,"2026-02-30":5,"bad":8,"2026-11-06":0,"2026-11-05":"5"}'))), { "2026-11-07": 12 });
    assert.deepEqual(plain(P.cleanHistory(null)), {});
    assert.deepEqual(plain(P.cleanHistory([])), {});
});

test("display rounds remaining seconds upward without fractional seconds", () => {
    assert.equal(P.formatTime(1499999), "25:00");
    assert.equal(P.formatTime(1), "00:01");
    assert.equal(P.formatTime(0), "00:00");
    assert.equal(P.formatTime(65000, true), "01\n05");
});

test("presets accept custom pairs, deduplicate and reject invalid durations", () => {
    const presets = P.parsePresets(" 25 / 5, 50/10;90/15\n25/5, 0/5, 5/0, 1441/5, 25.5/5, garbage");
    assert.deepEqual(plain(presets), [
        { key: "25/5", workMinutes: 25, breakMinutes: 5, longBreakMinutes: 15 },
        { key: "50/10", workMinutes: 50, breakMinutes: 10, longBreakMinutes: 15 },
        { key: "90/15", workMinutes: 90, breakMinutes: 15, longBreakMinutes: 15 },
    ]);
    assert.equal(P.activePreset(presets, "50/10").workMinutes, 50);
    assert.equal(P.activePreset(presets, "removed").key, "25/5");
    for (const value of [undefined, null, "", "invalid", "0/0", "1/1441"]) {
        assert.deepEqual(plain(P.parsePresets(value).map((preset: { key: string }) => preset.key)), ["25/5", "50/10"]);
    }
});

test("switching presets preserves running time and all work when shrinking then enlarging", () => {
    let timer = P.toggle(P.createTimer("work", 50), start);
    timer = P.toggle(timer, start + 30 * 60000);
    timer = P.resize(timer, 25, start + 31 * 60000);
    assert.equal(timer.remainingMs, 0);
    assert.equal(timer.elapsedMs, 30 * 60000);
    timer = P.resize(timer, 50, start + 32 * 60000);
    assert.equal(timer.remainingMs, 20 * 60000);
    timer = P.toggle(timer, start + 33 * 60000);
    const result = P.finish(timer, {}, start + 53 * 60000, 50);
    assert.equal(result.minutes, 50);

    const running = P.resize(P.toggle(P.createTimer("work", 25), start), 50, start + 10 * 60000);
    assert.equal(running.running, true);
    assert.equal(running.remainingMs, 40 * 60000);
});

test("quick actions can be configured individually, including optional long breaks", () => {
    assert.deepEqual(plain(P.quickActions({})), ["work", "shortBreak", "dashboard"]);
    assert.deepEqual(plain(P.quickActions({ showLongBreakAction: true })), ["work", "shortBreak", "longBreak", "dashboard"]);
    assert.deepEqual(plain(P.quickActions({ showWorkAction: false, showDashboardAction: false, showLongBreakAction: true })), ["shortBreak", "longBreak"]);
    assert.deepEqual(plain(P.quickActions({ showWorkAction: false, showShortBreakAction: false, showDashboardAction: false })), []);
});

test("long breaks use their own duration and never add to work statistics", () => {
    const preset = P.parsePresets("50/10")[0];
    assert.equal(P.durationForMode("work", preset, 20), 50);
    assert.equal(P.durationForMode("shortBreak", preset, 20), 10);
    assert.equal(P.durationForMode("longBreak", preset, 20), 20);
    const timer = P.toggle(P.createTimer("longBreak", 20), start);
    const result = P.finish(timer, { "2026-11-07": 12 }, start + 20 * 60000, 50);
    assert.equal(result.minutes, 0);
    assert.deepEqual(plain(result.history), { "2026-11-07": 12 });
    assert.equal(result.timer.mode, "work");
    assert.equal(result.timer.remainingMs, 50 * 60000);
});

test("stopwatch starts at zero, runs without a time limit, and records whole minutes once", () => {
    const initial = P.createTimer("stopwatch", 25);
    assert.equal(P.displayMs(initial), 0);
    const running = P.toggle(initial, start);
    assert.equal(P.tick(running, start + 3 * 3600000).elapsedMs, 3 * 3600000);
    assert.equal(P.tick(running, start + 3 * 3600000).remainingMs, 0);
    const saved = P.finish(running, {}, start + 760000, 25, "stopwatch");
    assert.equal(saved.minutes, 12);
    assert.equal(saved.timer.mode, "stopwatch");
    assert.equal(saved.timer.elapsedMs, 0);
    assert.equal(saved.timer.running, false);
    assert.deepEqual(plain(saved.history), { "2026-11-07": 12 });
    assert.equal(P.finish(saved.timer, saved.history, start + 1000000, 25, "stopwatch").minutes, 0);
    assert.equal(P.displayMs(P.tick(running, start + 999)), 0);
    assert.equal(P.displayMs(P.tick(running, start + 1000)), 1000);
});

test("stopwatch pauses exclude idle time and switching work modes preserves elapsed work", () => {
    let timer = P.toggle(P.createTimer("stopwatch", 0), start);
    timer = P.toggle(timer, start + 60500);
    timer = P.toggle(timer, start + 3600000);
    const saved = P.finish(timer, {}, start + 3659500, 25, "stopwatch");
    assert.equal(saved.minutes, 2);
    let countdown = P.toggle(P.createTimer("work", 25), start);
    let stopwatch = P.changeWorkMode(countdown, "stopwatch", 25, start + 600000);
    assert.equal(stopwatch.elapsedMs, 600000);
    assert.equal(stopwatch.running, true);
    assert.equal(P.resize(stopwatch, 1, start + 1200000).elapsedMs, 1200000);
    countdown = P.changeWorkMode(stopwatch, "work", 50, start + 900000);
    assert.equal(countdown.remainingMs, 35 * 60000);
    assert.equal(P.finish(countdown, {}, start + 900000, 50).minutes, 15);
});

test("stopwatch crossing midnight contributes to daily totals and streaks", () => {
    const begin = at("2026-11-07T23:58:00");
    const result = P.finish(P.toggle(P.createTimer("stopwatch", 0), begin), {}, begin + 300000, 25, "stopwatch");
    assert.deepEqual(plain(result.history), { "2026-11-07": 2, "2026-11-08": 3 });
    assert.equal(P.streak(result.history, new Date(begin + 300000)), 2);
    assert.equal(P.hasUnrecordedWork(result.timer), false);
});

test("three-field profiles migrate legacy values and keep per-preset long breaks", () => {
    const legacy = P.profileRows("25/5, 50/10", 20);
    assert.equal(legacy[0].longBreakMinutes, 20);
    let rows = P.appendProfile(legacy);
    assert.equal(rows.length, 3);
    rows = P.editProfile(rows, 2, "workMinutes", "45");
    rows = P.editProfile(rows, 2, "breakMinutes", "9");
    rows = P.editProfile(rows, 2, "longBreakMinutes", "22");
    assert.equal(P.parsePresets(rows)[2].key, "45/9/22");
    assert.equal(P.activePreset(P.parsePresets(rows), "50/10").key, "50/10/20");
    for (const invalid of ["", 0, -1, 1441, 1.5, "abc"]) {
        assert.equal(P.editProfile(rows, 2, "workMinutes", invalid), rows);
    }
    const duplicate = P.appendProfile(P.profileRows("25/5"));
    assert.equal(P.profileRows(duplicate).length, 2);
    assert.equal(P.parsePresets(duplicate).length, 1);
    rows = P.removeProfile(rows, 2);
    assert.equal(rows.length, 2);
    rows = P.removeProfile(rows, 1);
    assert.equal(P.removeProfile(rows, 0).length, 1);
});
