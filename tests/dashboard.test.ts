import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";
import test from "node:test";

const context = vm.createContext({ Date });
vm.runInContext(readFileSync(new URL("../Pomodoro.js", import.meta.url), "utf8"), context);
const P = context.Pomodoro;
const plain = (value: unknown) => JSON.parse(JSON.stringify(value));
const now = new Date("2026-11-07T12:00:00");
const history = { "2026-10-26": 40, "2026-11-01": 60, "2026-11-02": 30, "2026-11-06": 60, "2026-11-07": 90 };

test("legacy daily history produces accurate weekly totals and goals without invented session counts", () => {
    const result = P.dashboardSummary(history, P.cleanSessionStats({}), now, 60);
    assert.equal(result.totalMinutes, 280);
    assert.equal(result.weekMinutes, 180);
    assert.equal(result.previousWeekMinutes, 100);
    assert.equal(result.weekChange, 80);
    assert.equal(result.goalsHit, 3);
    assert.equal(result.streakDays, 2);
    assert.equal(result.bestWeekday, 6);
    assert.equal(result.averageMinutes, null);
    assert.equal(result.peakHour, null);
    assert.equal(result.totalSessions, 0);
    assert.equal(P.dashboardSummary(history, P.cleanSessionStats({}), now, 0).goalsHit, 0);
});

test("recorded sessions track real hourly work, counts and means; breaks and subminute work are excluded", () => {
    const start = new Date("2026-11-07T09:50:00").getTime();
    let stats = P.cleanSessionStats({});
    let timer = P.tick(P.toggle(P.createTimer("stopwatch", 0), start), start + 20 * 60000);
    stats = P.recordSessionStats(stats, timer, 20, start + 20 * 60000);
    assert.equal(stats.hourlyMs["9"], 10 * 60000);
    assert.equal(stats.hourlyMs["10"], 10 * 60000);
    timer = P.tick(P.toggle(P.createTimer("work", 25), start + 30 * 60000), start + 35 * 60000);
    stats = P.recordSessionStats(stats, timer, 5, start + 35 * 60000);
    const result = P.dashboardSummary({ "2026-11-07": 25 }, stats, now, 60);
    assert.equal(result.sessionsThisWeek, 2);
    assert.equal(result.totalSessions, 2);
    assert.equal(result.averageMinutes, 12.5);
    assert.equal(result.peakHour, 10);
    assert.equal(stats.trackingSince, "2026-11-07");
    assert.equal(P.recordSessionStats(stats, P.createTimer("longBreak", 15), 15, start), stats);
    assert.equal(P.recordSessionStats(stats, P.createTimer("work", 25), 0, start), stats);
    const restored = P.cleanSessionStats(JSON.parse(JSON.stringify(stats)));
    assert.deepEqual(plain(restored), plain(stats));
});

test("day, week and month charts include the full recorded history through the current period", () => {
    assert.equal(P.dashboardChart(history, now, "days").length, 13);
    const weeks = P.dashboardChart(history, now, "weeks");
    assert.equal(weeks.length, 2);
    assert.equal(weeks.at(-1).key, "2026-11-02");
    assert.equal(weeks.at(-1).minutes, 180);
    assert.equal(weeks.at(-2).minutes, 100);
    assert.equal(P.dashboardChart(history, now, "months").at(-1).minutes, 240);
    assert.equal(P.dashboardChart(history, now, "months").length, 2);
    assert.equal(P.dashboardChart(history, now, "years").at(-1).minutes, 280);
    const weekdays = P.dashboardChart(history, now, "weekday");
    assert.equal(weekdays[0].weekdayIndex, 1);
    assert.equal(weekdays[0].minutes, 70);
    assert.equal(weekdays[5].minutes, 90);
    assert.equal(P.dashboardHasEarlier(history, weekdays, "weekday"), false);
    const older = { ...history, "2020-01-01": 15 };
    const allWeeks = P.dashboardChart(older, now, "weeks");
    assert.equal(allWeeks[0].key, "2019-12-30");
    assert.equal(P.dashboardHasEarlier(older, allWeeks, "weeks"), false);
    assert.deepEqual(plain(P.dashboardChart(history, now, "weeks", 1)), plain(weeks));
});

test("full-range charts preserve empty periods, leap days and DST across multiple years", () => {
    const recorded = { "2024-02-28": 10, "2024-03-31": 20, "2026-11-07": 30 };
    const days = P.dashboardChart(recorded, now, "days");
    assert.equal(days[0].key, "2024-02-28");
    assert.equal(days.at(-1).key, "2026-11-07");
    assert.ok(days.length > 900);
    assert.equal(days.find((bar: { key: string }) => bar.key === "2024-02-29").minutes, 0);
    assert.equal(days.find((bar: { key: string }) => bar.key === "2024-03-31").minutes, 20);
    assert.equal(days.reduce((sum: number, bar: { minutes: number }) => sum + bar.minutes, 0), 60);
    const months = P.dashboardChart(recorded, now, "months");
    assert.equal(months.length, 34);
    assert.equal(months[0].key, "2024-02");
    assert.equal(months.at(-1).key, "2026-11");
    assert.equal(months[2].minutes, 0);
    const weeks = P.dashboardChart(recorded, now, "weeks");
    assert.ok(weeks.length > 100);
    assert.equal(weeks[0].key, "2024-02-26");
    assert.equal(weeks.at(-1).key, "2026-11-02");
    for (const grouping of ["days", "weeks", "months"]) {
        const bars = P.dashboardChart({}, now, grouping);
        assert.equal(bars.length, 1);
        assert.equal(bars[0].minutes, 0);
        assert.equal(P.dashboardChart({ "2026-12-01": 20 }, now, grouping).length, 1);
        assert.equal(P.dashboardHasEarlier(recorded, P.dashboardChart(recorded, now, grouping), grouping), false);
    }
});

test("daily goals and empty or damaged session statistics have safe defaults", () => {
    assert.equal(P.dailyGoal("90"), 90);
    assert.equal(P.dailyGoal(0), 0);
    for (const value of [undefined, null, "", "bad", -1, 1441]) assert.equal(P.dailyGoal(value), 60);
    const cleaned = P.cleanSessionStats({ sessionsByDay: { bad: 2 }, hourlyMs: { 25: 5000, 14: -1 } });
    assert.deepEqual(plain(cleaned), { sessionsByDay: {}, minutesByDay: {}, hourlyMs: {}, trackingSince: "" });
});

test("dashboard streak follows its own minimum independently of the daily goal", () => {
    const stats = P.cleanSessionStats({});
    const summary = P.dashboardSummary(history, stats, now, 60, 75);
    assert.equal(summary.streakDays, 1);
    assert.equal(summary.goalsHit, 3);
    assert.equal(summary.totalMinutes, 280);
    assert.equal(P.dashboardSummary(history, stats, now, 0, 100).streakDays, 0);
});

test("weekly comparisons handle growth, declines, no change and missing baselines", () => {
    const stats = P.cleanSessionStats({ sessionsByDay: { "2026-10-26": 2, "2026-11-02": 3 } });
    const summary = P.dashboardSummary(history, stats, now, 60);
    assert.equal(summary.sessionsWeekChange, 50);
    assert.equal(P.dashboardSummary({}, P.cleanSessionStats({}), now, 60).sessionsWeekChange, null);
    for (const [minutes, expected] of [[50, -50], [100, 0], [150, 50], [0, -100]]) {
        const recorded = { "2026-10-26": 100, "2026-11-02": minutes };
        assert.equal(P.dashboardSummary(recorded, stats, now, 60).weekChange, expected);
    }
    assert.equal(P.dashboardSummary({ "2026-11-02": 30 }, stats, now, 60).weekChange, null);
    assert.equal(P.dashboardSummary({}, stats, now, 60).weekChange, 0);
});
