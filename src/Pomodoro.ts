// Compiled as a namespace: QML imports Pomodoro.js without a CommonJS/ESM loader.
namespace Pomodoro {
    export type History = Record<string, number>;
    export type Grouping = "days" | "months" | "years";
    export type WorkMode = "work" | "stopwatch";
    export type Mode = WorkMode | "shortBreak" | "longBreak";
    export type QuickAction = Exclude<Mode, "stopwatch"> | "dashboard";

    export function isWorkMode(mode: Mode): boolean {
        return mode === "work" || mode === "stopwatch";
    }

    export function hasUnrecordedWork(timer: TimerState): boolean {
        return isWorkMode(timer.mode) && (timer.elapsedMs ?? timer.durationMs - timer.remainingMs) > 0;
    }

    export function quickActions(settings: Record<string, unknown>): QuickAction[] {
        const result: QuickAction[] = [];
        if (settings.showWorkAction !== false) result.push("work");
        if (settings.showShortBreakAction !== false) result.push("shortBreak");
        if (settings.showLongBreakAction === true) result.push("longBreak");
        if (settings.showDashboardAction !== false) result.push("dashboard");
        return result;
    }

    export function durationForMode(mode: Mode, preset: Preset, longBreakMinutes: number): number {
        return mode === "stopwatch" ? 0 : mode === "work" ? preset.workMinutes : mode === "longBreak" ? longBreakMinutes : preset.breakMinutes;
    }
    export interface TimerProfile {
        workMinutes: number;
        breakMinutes: number;
        longBreakMinutes: number;
    }
    export interface Preset extends TimerProfile {
        key: string;
    }

    export function profileRows(value: unknown, legacyLongBreak = 15): TimerProfile[] {
        const rows: TimerProfile[] = [];
        const longBreakMinutes = validDuration(legacyLongBreak, 15);
        if (Array.isArray(value)) {
            for (const item of value) {
                if (!item || typeof item !== "object") continue;
                const row = {
                    workMinutes: Number(item.workMinutes),
                    breakMinutes: Number(item.breakMinutes),
                    longBreakMinutes: Number(item.longBreakMinutes)
                };
                if (Object.keys(row).every(key => isValidMinutes(row[key as keyof TimerProfile])))
                    rows.push(row);
            }
        }
        if (typeof value === "string") {
            value.split(/[,;\n]+/).forEach(entry => {
                const match = /^\s*(\d+)\s*\/\s*(\d+)\s*$/.exec(entry);
                if (!match) return;
                const workMinutes = Number(match[1]);
                const breakMinutes = Number(match[2]);
                if (isValidMinutes(workMinutes) && isValidMinutes(breakMinutes))
                    rows.push({ workMinutes, breakMinutes, longBreakMinutes });
            });
        }
        return rows.length > 0 ? rows : [
            { workMinutes: 25, breakMinutes: 5, longBreakMinutes },
            { workMinutes: 50, breakMinutes: 10, longBreakMinutes }
        ];
    }

    function isValidMinutes(value: number): boolean {
        return Number.isInteger(value) && value >= 1 && value <= 1440;
    }

    export function parsePresets(value: unknown, legacyLongBreak = 15): Preset[] {
        const presets: Preset[] = [];
        for (const row of profileRows(value, legacyLongBreak)) {
            const key = row.workMinutes + "/" + row.breakMinutes + (Array.isArray(value) ? "/" + row.longBreakMinutes : "");
            if (!presets.some(preset => preset.key === key))
                presets.push({ key, ...row });
        }
        return presets;
    }

    export function editProfile(rows: TimerProfile[], index: number, field: keyof TimerProfile, value: unknown): TimerProfile[] {
        const minutes = Number(value);
        if (!rows[index] || !["workMinutes", "breakMinutes", "longBreakMinutes"].includes(field) || !isValidMinutes(minutes))
            return rows;
        if (rows[index][field] === minutes) return rows;
        return rows.map((row, rowIndex) => rowIndex === index ? { ...row, [field]: minutes } : { ...row });
    }

    export function appendProfile(rows: TimerProfile[]): TimerProfile[] {
        return [...rows, { workMinutes: 25, breakMinutes: 5, longBreakMinutes: 15 }];
    }

    export function removeProfile(rows: TimerProfile[], index: number): TimerProfile[] {
        return rows.length > 1 && rows[index] ? rows.filter((_, rowIndex) => rowIndex !== index) : rows;
    }

    export function activePreset(presets: Preset[], selectedKey: string): Preset {
        return presets.find(preset => preset.key === selectedKey)
            || presets.find(preset => preset.workMinutes + "/" + preset.breakMinutes === selectedKey)
            || presets[0];
    }
    export interface TimerState {
        mode: Mode;
        durationMs: number;
        remainingMs: number;
        elapsedMs: number;
        running: boolean;
        lastTickMs: number;
        workByDay: History;
        workByHour?: History;
    }
    export interface Bar {
        key: string;
        label: string;
        minutes: number;
        current: boolean;
        monthIndex: number;
    }

    export function dateKey(date: Date): string {
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0");
    }

    function localDate(key: string): Date {
        const parts = key.split("-").map(Number);
        return new Date(parts[0], parts[1] - 1, parts[2], 12);
    }

    export function validDuration(value: unknown, fallback: number): number {
        const n = Number(value);
        return Number.isFinite(n) && n >= 1 ? Math.min(1440, Math.floor(n)) : fallback;
    }

    export function cleanHistory(value: unknown): History {
        const result: History = {};
        if (!value || typeof value !== "object" || Array.isArray(value)) return result;
        Object.keys(value).forEach(key => {
            const minutes = (value as Record<string, unknown>)[key];
            if (/^\d{4}-\d{2}-\d{2}$/.test(key) && dateKey(localDate(key)) === key && typeof minutes === "number" && Number.isFinite(minutes) && minutes >= 1)
                result[key] = Math.floor(minutes);
        });
        return result;
    }

    // Split active intervals at local midnight, including daylight saving changes.
    export function addInterval(buckets: History, startMs: number, endMs: number): History {
        const result = { ...buckets };
        while (startMs < endMs) {
            const date = new Date(startMs);
            const midnight = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();
            const until = Math.min(endMs, midnight);
            const key = dateKey(date);
            result[key] = (result[key] || 0) + until - startMs;
            startMs = until;
        }
        return result;
    }

    // Floor once per session; fractions carry across midnight within that session.
    export function recordSession(history: History, buckets: History): { history: History; minutes: number } {
        const result = { ...history };
        let accumulatedMs = 0;
        let assigned = 0;
        Object.keys(buckets).sort().forEach(key => {
            accumulatedMs += buckets[key];
            const whole = Math.floor(accumulatedMs / 60000);
            const minutes = whole - assigned;
            if (minutes > 0) result[key] = (result[key] || 0) + minutes;
            assigned = whole;
        });
        return { history: result, minutes: assigned };
    }

    export function totalMinutes(history: History): number {
        return Object.keys(history).reduce((total, key) => total + history[key], 0);
    }

    export function streak(history: History, now: Date): number {
        const cursor = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12);
        if (!(history[dateKey(cursor)] >= 1)) cursor.setDate(cursor.getDate() - 1);
        let days = 0;
        while (history[dateKey(cursor)] >= 1) {
            days++;
            cursor.setDate(cursor.getDate() - 1);
        }
        return days;
    }

    function periodStart(now: Date, grouping: Grouping): Date {
        return new Date(now.getFullYear(), grouping === "years" ? 0 : now.getMonth(), grouping === "days" ? now.getDate() : 1, 12);
    }

    function movePeriod(date: Date, grouping: Grouping, offset: number): Date {
        const result = new Date(date);
        if (grouping === "years") result.setFullYear(result.getFullYear() + offset);
        else if (grouping === "months") result.setMonth(result.getMonth() + offset);
        else result.setDate(result.getDate() + offset);
        return result;
    }

    function periodKey(date: Date, grouping: Grouping): string {
        return dateKey(date).slice(0, grouping === "years" ? 4 : grouping === "months" ? 7 : 10);
    }

    export function chart(history: History, now: Date, grouping: Grouping, offset: number, count: number): Bar[] {
        const end = movePeriod(periodStart(now, grouping), grouping, -offset * count);
        const sums: History = {};
        Object.keys(history).forEach(key => {
            const bucket = key.slice(0, grouping === "years" ? 4 : grouping === "months" ? 7 : 10);
            sums[bucket] = (sums[bucket] || 0) + history[key];
        });
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const result: Bar[] = [];
        for (let i = count - 1; i >= 0; i--) {
            const date = movePeriod(end, grouping, -i);
            const key = periodKey(date, grouping);
            const label = grouping === "years" ? String(date.getFullYear()) : grouping === "months" ? months[date.getMonth()] : String(date.getDate()) + "/" + (date.getMonth() + 1);
            result.push({ key, label, minutes: sums[key] || 0, current: key === periodKey(now, grouping), monthIndex: grouping === "months" ? date.getMonth() : -1 });
        }
        return result;
    }

    export function maxMinutes(data: Bar[]): number {
        return data.reduce((max, item) => Math.max(max, item.minutes), 1);
    }

    export function hasEarlier(history: History, data: Bar[], grouping: Grouping): boolean {
        return data.length > 0 && Object.keys(history).some(key =>
            key.slice(0, grouping === "years" ? 4 : grouping === "months" ? 7 : 10) < data[0].key);
    }

    export function createTimer(mode: Mode, minutes: number): TimerState {
        const durationMs = mode === "stopwatch" ? 0 : minutes * 60000;
        return { mode, durationMs, remainingMs: durationMs, elapsedMs: 0, running: false, lastTickMs: 0, workByDay: {}, workByHour: {} };
    }

    export function tick(timer: TimerState, nowMs: number): TimerState {
        if (!timer.running) return timer;
        const sinceLastTick = Math.max(0, nowMs - timer.lastTickMs);
        const elapsed = timer.mode === "stopwatch" ? sinceLastTick : Math.min(sinceLastTick, timer.remainingMs);
        return {
            ...timer,
            remainingMs: timer.mode === "stopwatch" ? 0 : timer.remainingMs - elapsed,
            elapsedMs: (timer.elapsedMs ?? timer.durationMs - timer.remainingMs) + elapsed,
            lastTickMs: nowMs,
            workByDay: isWorkMode(timer.mode) ? addInterval(timer.workByDay, timer.lastTickMs, timer.lastTickMs + elapsed) : timer.workByDay,
            workByHour: isWorkMode(timer.mode) ? addHourlyInterval(timer.workByHour || {}, timer.lastTickMs, timer.lastTickMs + elapsed) : timer.workByHour
        };
    }

    export function toggle(timer: TimerState, nowMs: number): TimerState {
        if (timer.running) return { ...tick(timer, nowMs), running: false };
        return { ...timer, running: true, lastTickMs: nowMs };
    }

    export function resize(timer: TimerState, minutes: number, nowMs: number): TimerState {
        const current = tick(timer, nowMs);
        if (current.mode === "stopwatch") return current;
        const durationMs = minutes * 60000;
        const elapsed = current.elapsedMs ?? current.durationMs - current.remainingMs;
        return { ...current, durationMs, remainingMs: Math.max(0, durationMs - elapsed) };
    }

    export function changeWorkMode(timer: TimerState, mode: WorkMode, workMinutes: number, nowMs: number): TimerState {
        if (!isWorkMode(timer.mode)) return timer;
        const current = tick(timer, nowMs);
        const elapsedMs = current.elapsedMs ?? current.durationMs - current.remainingMs;
        const durationMs = mode === "stopwatch" ? 0 : workMinutes * 60000;
        return { ...current, mode, elapsedMs, durationMs, remainingMs: Math.max(0, durationMs - elapsedMs) };
    }

    export function finish(timer: TimerState, history: History, nowMs: number, workMinutes: number, nextMode: WorkMode = "work"): { timer: TimerState; history: History; minutes: number } {
        const current = tick(timer, nowMs);
        const record = recordSession(history, isWorkMode(current.mode) ? current.workByDay : {});
        return { timer: createTimer(nextMode, workMinutes), history: record.history, minutes: record.minutes };
    }

    export function displayMs(timer: TimerState): number {
        return timer.mode === "stopwatch" ? Math.floor(timer.elapsedMs / 1000) * 1000 : timer.remainingMs;
    }

    export function formatTime(remainingMs: number, vertical = false): string {
        const seconds = Math.max(0, Math.ceil(remainingMs / 1000));
        return String(Math.floor(seconds / 60)).padStart(2, "0") + (vertical ? "\n" : ":") + String(seconds % 60).padStart(2, "0");
    }
}
