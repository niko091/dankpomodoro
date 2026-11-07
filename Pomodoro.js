"use strict";
var Pomodoro;
(function (Pomodoro) {
    function addHourlyInterval(buckets, startMs, endMs) {
        const result = Object.assign({}, buckets);
        while (startMs < endMs) {
            const date = new Date(startMs);
            const withinHour = date.getMinutes() * 60000 + date.getSeconds() * 1000 + date.getMilliseconds();
            const until = Math.min(endMs, startMs + 3600000 - withinHour);
            const key = String(date.getHours());
            result[key] = (result[key] || 0) + until - startMs;
            startMs = until;
        }
        return result;
    }
    Pomodoro.addHourlyInterval = addHourlyInterval;
    function cleanSessionStats(value) {
        const source = value && typeof value === "object" ? value : {};
        const hourlyMs = {};
        if (source.hourlyMs && typeof source.hourlyMs === "object") {
            for (const [hour, ms] of Object.entries(source.hourlyMs)) {
                if (/^(\d|1\d|2[0-3])$/.test(hour) && typeof ms === "number" && Number.isFinite(ms) && ms > 0)
                    hourlyMs[hour] = ms;
            }
        }
        const sessionsByDay = Pomodoro.cleanHistory(source.sessionsByDay);
        return {
            sessionsByDay,
            minutesByDay: Pomodoro.cleanHistory(source.minutesByDay),
            hourlyMs,
            trackingSince: Object.keys(sessionsByDay).sort()[0] || ""
        };
    }
    Pomodoro.cleanSessionStats = cleanSessionStats;
    function recordSessionStats(stats, timer, minutes, nowMs) {
        if (!Pomodoro.isWorkMode(timer.mode) || minutes < 1)
            return stats;
        const key = Pomodoro.dateKey(new Date(nowMs));
        const recorded = Pomodoro.recordSession({}, timer.workByDay);
        const minutesByDay = Object.assign({}, stats.minutesByDay);
        for (const day of Object.keys(recorded.history))
            minutesByDay[day] = (minutesByDay[day] || 0) + recorded.history[day];
        const hourlyMs = Object.assign({}, stats.hourlyMs);
        for (const hour of Object.keys(timer.workByHour || {}))
            hourlyMs[hour] = (hourlyMs[hour] || 0) + (timer.workByHour || {})[hour];
        return {
            sessionsByDay: Object.assign(Object.assign({}, stats.sessionsByDay), { [key]: (stats.sessionsByDay[key] || 0) + 1 }),
            minutesByDay,
            hourlyMs,
            trackingSince: stats.trackingSince || key
        };
    }
    Pomodoro.recordSessionStats = recordSessionStats;
    function dailyGoal(value) {
        const minutes = Number(value);
        return value !== undefined && value !== null && value !== "" && Number.isInteger(minutes) && minutes >= 0 && minutes <= 1440 ? minutes : 60;
    }
    Pomodoro.dailyGoal = dailyGoal;
    function dashboardDate(key) {
        const parts = key.split("-").map(Number);
        return new Date(parts[0], parts[1] - 1, parts[2], 12);
    }
    function monday(date) {
        const result = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
        result.setDate(result.getDate() - (result.getDay() + 6) % 7);
        return result;
    }
    function sumPeriod(history, begin, end) {
        return Object.keys(history).reduce((total, key) => total + (key >= begin && key <= end ? history[key] : 0), 0);
    }
    function dashboardSummary(history, stats, now, goal) {
        const today = Pomodoro.dateKey(now);
        const start = monday(now);
        const previous = new Date(start);
        previous.setDate(previous.getDate() - 7);
        const previousEnd = new Date(start);
        previousEnd.setDate(previousEnd.getDate() - 1);
        const weekMinutes = sumPeriod(history, Pomodoro.dateKey(start), today);
        const previousWeekMinutes = sumPeriod(history, Pomodoro.dateKey(previous), Pomodoro.dateKey(previousEnd));
        const totalSessions = Pomodoro.totalMinutes(stats.sessionsByDay);
        const trackedMinutes = Pomodoro.totalMinutes(stats.minutesByDay);
        const weekdays = [0, 0, 0, 0, 0, 0, 0];
        let goalsHit = 0;
        for (const day of Object.keys(history)) {
            if (day > today)
                continue;
            weekdays[dashboardDate(day).getDay()] += history[day];
            if (goal > 0 && day.slice(0, 7) === today.slice(0, 7) && history[day] >= goal)
                goalsHit++;
        }
        let peakHour = null;
        let peakMs = 0;
        for (let hour = 0; hour < 24; hour++) {
            if ((stats.hourlyMs[hour] || 0) > peakMs) {
                peakMs = stats.hourlyMs[hour];
                peakHour = hour;
            }
        }
        const bestMinutes = Math.max(...weekdays);
        return {
            totalMinutes: Pomodoro.totalMinutes(history),
            totalSessions,
            weekMinutes,
            previousWeekMinutes,
            weekChange: previousWeekMinutes > 0 ? Math.round((weekMinutes - previousWeekMinutes) / previousWeekMinutes * 100) : null,
            sessionsThisWeek: sumPeriod(stats.sessionsByDay, Pomodoro.dateKey(start), today),
            averageMinutes: totalSessions > 0 ? Math.round(trackedMinutes / totalSessions * 10) / 10 : null,
            goalsHit,
            peakHour,
            bestWeekday: bestMinutes > 0 ? weekdays.indexOf(bestMinutes) : null,
            streakDays: Pomodoro.streak(history, now)
        };
    }
    Pomodoro.dashboardSummary = dashboardSummary;
    function dashboardChart(history, now, grouping, page = 0) {
        const today = Pomodoro.dateKey(now);
        const recorded = {};
        for (const day of Object.keys(history)) {
            if (day <= today && history[day] > 0)
                recorded[day] = history[day];
        }
        const firstKey = Object.keys(recorded).sort()[0] || today;
        const firstDate = dashboardDate(firstKey);
        if (grouping === "weekday") {
            const values = [0, 0, 0, 0, 0, 0, 0];
            for (const day of Object.keys(recorded))
                values[(dashboardDate(day).getDay() + 6) % 7] += recorded[day];
            return values.map((minutes, index) => ({ key: String(index), label: "", minutes, current: index === (now.getDay() + 6) % 7, monthIndex: -1, weekdayIndex: (index + 1) % 7 }));
        }
        if (grouping === "days") {
            // Calendar dates, not elapsed 24-hour intervals: DST days can have 23 or 25 hours.
            const firstDay = Date.UTC(firstDate.getFullYear(), firstDate.getMonth(), firstDate.getDate());
            const lastDay = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
            return Pomodoro.chart(recorded, now, "days", 0, Math.round((lastDay - firstDay) / 86400000) + 1);
        }
        if (grouping === "months") {
            const count = (now.getFullYear() - firstDate.getFullYear()) * 12 + now.getMonth() - firstDate.getMonth() + 1;
            return Pomodoro.chart(recorded, now, "months", 0, count);
        }
        if (grouping === "years")
            return Pomodoro.chart(recorded, now, "years", page, 10);
        const weekly = {};
        for (const day of Object.keys(recorded)) {
            const key = Pomodoro.dateKey(monday(dashboardDate(day)));
            weekly[key] = (weekly[key] || 0) + recorded[day];
        }
        const end = monday(now);
        const data = [];
        for (const date = monday(firstDate); date <= end; date.setDate(date.getDate() + 7)) {
            const key = Pomodoro.dateKey(date);
            data.push({ key, label: String(date.getDate()) + "/" + (date.getMonth() + 1), minutes: weekly[key] || 0, current: key === Pomodoro.dateKey(monday(now)), monthIndex: -1 });
        }
        return data;
    }
    Pomodoro.dashboardChart = dashboardChart;
    function dashboardHasEarlier(history, data, grouping) {
        return grouping === "years" && Pomodoro.hasEarlier(history, data, "years");
    }
    Pomodoro.dashboardHasEarlier = dashboardHasEarlier;
})(Pomodoro || (Pomodoro = {}));
// Compiled as a namespace: QML imports Pomodoro.js without a CommonJS/ESM loader.
var Pomodoro;
(function (Pomodoro) {
    function isWorkMode(mode) {
        return mode === "work" || mode === "stopwatch";
    }
    Pomodoro.isWorkMode = isWorkMode;
    function hasUnrecordedWork(timer) {
        var _a;
        return isWorkMode(timer.mode) && ((_a = timer.elapsedMs) !== null && _a !== void 0 ? _a : timer.durationMs - timer.remainingMs) > 0;
    }
    Pomodoro.hasUnrecordedWork = hasUnrecordedWork;
    function quickActions(settings) {
        const result = [];
        if (settings.showWorkAction !== false)
            result.push("work");
        if (settings.showShortBreakAction !== false)
            result.push("shortBreak");
        if (settings.showLongBreakAction === true)
            result.push("longBreak");
        if (settings.showDashboardAction !== false)
            result.push("dashboard");
        return result;
    }
    Pomodoro.quickActions = quickActions;
    function durationForMode(mode, preset, longBreakMinutes) {
        return mode === "stopwatch" ? 0 : mode === "work" ? preset.workMinutes : mode === "longBreak" ? longBreakMinutes : preset.breakMinutes;
    }
    Pomodoro.durationForMode = durationForMode;
    function profileRows(value, legacyLongBreak = 15) {
        const rows = [];
        const longBreakMinutes = validDuration(legacyLongBreak, 15);
        if (Array.isArray(value)) {
            for (const item of value) {
                if (!item || typeof item !== "object")
                    continue;
                const row = {
                    workMinutes: Number(item.workMinutes),
                    breakMinutes: Number(item.breakMinutes),
                    longBreakMinutes: Number(item.longBreakMinutes)
                };
                if (Object.keys(row).every(key => isValidMinutes(row[key])))
                    rows.push(row);
            }
        }
        if (typeof value === "string") {
            value.split(/[,;\n]+/).forEach(entry => {
                const match = /^\s*(\d+)\s*\/\s*(\d+)\s*$/.exec(entry);
                if (!match)
                    return;
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
    Pomodoro.profileRows = profileRows;
    function isValidMinutes(value) {
        return Number.isInteger(value) && value >= 1 && value <= 1440;
    }
    function parsePresets(value, legacyLongBreak = 15) {
        const presets = [];
        for (const row of profileRows(value, legacyLongBreak)) {
            const key = row.workMinutes + "/" + row.breakMinutes + (Array.isArray(value) ? "/" + row.longBreakMinutes : "");
            if (!presets.some(preset => preset.key === key))
                presets.push(Object.assign({ key }, row));
        }
        return presets;
    }
    Pomodoro.parsePresets = parsePresets;
    function editProfile(rows, index, field, value) {
        const minutes = Number(value);
        if (!rows[index] || !["workMinutes", "breakMinutes", "longBreakMinutes"].includes(field) || !isValidMinutes(minutes))
            return rows;
        if (rows[index][field] === minutes)
            return rows;
        return rows.map((row, rowIndex) => rowIndex === index ? Object.assign(Object.assign({}, row), { [field]: minutes }) : Object.assign({}, row));
    }
    Pomodoro.editProfile = editProfile;
    function appendProfile(rows) {
        return [...rows, { workMinutes: 25, breakMinutes: 5, longBreakMinutes: 15 }];
    }
    Pomodoro.appendProfile = appendProfile;
    function removeProfile(rows, index) {
        return rows.length > 1 && rows[index] ? rows.filter((_, rowIndex) => rowIndex !== index) : rows;
    }
    Pomodoro.removeProfile = removeProfile;
    function activePreset(presets, selectedKey) {
        return presets.find(preset => preset.key === selectedKey)
            || presets.find(preset => preset.workMinutes + "/" + preset.breakMinutes === selectedKey)
            || presets[0];
    }
    Pomodoro.activePreset = activePreset;
    function dateKey(date) {
        return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0");
    }
    Pomodoro.dateKey = dateKey;
    function localDate(key) {
        const parts = key.split("-").map(Number);
        return new Date(parts[0], parts[1] - 1, parts[2], 12);
    }
    function validDuration(value, fallback) {
        const n = Number(value);
        return Number.isFinite(n) && n >= 1 ? Math.min(1440, Math.floor(n)) : fallback;
    }
    Pomodoro.validDuration = validDuration;
    function cleanHistory(value) {
        const result = {};
        if (!value || typeof value !== "object" || Array.isArray(value))
            return result;
        Object.keys(value).forEach(key => {
            const minutes = value[key];
            if (/^\d{4}-\d{2}-\d{2}$/.test(key) && dateKey(localDate(key)) === key && typeof minutes === "number" && Number.isFinite(minutes) && minutes >= 1)
                result[key] = Math.floor(minutes);
        });
        return result;
    }
    Pomodoro.cleanHistory = cleanHistory;
    // Split active intervals at local midnight, including daylight saving changes.
    function addInterval(buckets, startMs, endMs) {
        const result = Object.assign({}, buckets);
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
    Pomodoro.addInterval = addInterval;
    // Floor once per session; fractions carry across midnight within that session.
    function recordSession(history, buckets) {
        const result = Object.assign({}, history);
        let accumulatedMs = 0;
        let assigned = 0;
        Object.keys(buckets).sort().forEach(key => {
            accumulatedMs += buckets[key];
            const whole = Math.floor(accumulatedMs / 60000);
            const minutes = whole - assigned;
            if (minutes > 0)
                result[key] = (result[key] || 0) + minutes;
            assigned = whole;
        });
        return { history: result, minutes: assigned };
    }
    Pomodoro.recordSession = recordSession;
    function totalMinutes(history) {
        return Object.keys(history).reduce((total, key) => total + history[key], 0);
    }
    Pomodoro.totalMinutes = totalMinutes;
    function streak(history, now) {
        const cursor = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 12);
        if (!(history[dateKey(cursor)] >= 1))
            cursor.setDate(cursor.getDate() - 1);
        let days = 0;
        while (history[dateKey(cursor)] >= 1) {
            days++;
            cursor.setDate(cursor.getDate() - 1);
        }
        return days;
    }
    Pomodoro.streak = streak;
    function periodStart(now, grouping) {
        return new Date(now.getFullYear(), grouping === "years" ? 0 : now.getMonth(), grouping === "days" ? now.getDate() : 1, 12);
    }
    function movePeriod(date, grouping, offset) {
        const result = new Date(date);
        if (grouping === "years")
            result.setFullYear(result.getFullYear() + offset);
        else if (grouping === "months")
            result.setMonth(result.getMonth() + offset);
        else
            result.setDate(result.getDate() + offset);
        return result;
    }
    function periodKey(date, grouping) {
        return dateKey(date).slice(0, grouping === "years" ? 4 : grouping === "months" ? 7 : 10);
    }
    function chart(history, now, grouping, offset, count) {
        const end = movePeriod(periodStart(now, grouping), grouping, -offset * count);
        const sums = {};
        Object.keys(history).forEach(key => {
            const bucket = key.slice(0, grouping === "years" ? 4 : grouping === "months" ? 7 : 10);
            sums[bucket] = (sums[bucket] || 0) + history[key];
        });
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const result = [];
        for (let i = count - 1; i >= 0; i--) {
            const date = movePeriod(end, grouping, -i);
            const key = periodKey(date, grouping);
            const label = grouping === "years" ? String(date.getFullYear()) : grouping === "months" ? months[date.getMonth()] : String(date.getDate()) + "/" + (date.getMonth() + 1);
            result.push({ key, label, minutes: sums[key] || 0, current: key === periodKey(now, grouping), monthIndex: grouping === "months" ? date.getMonth() : -1 });
        }
        return result;
    }
    Pomodoro.chart = chart;
    function maxMinutes(data) {
        return data.reduce((max, item) => Math.max(max, item.minutes), 1);
    }
    Pomodoro.maxMinutes = maxMinutes;
    function hasEarlier(history, data, grouping) {
        return data.length > 0 && Object.keys(history).some(key => key.slice(0, grouping === "years" ? 4 : grouping === "months" ? 7 : 10) < data[0].key);
    }
    Pomodoro.hasEarlier = hasEarlier;
    function createTimer(mode, minutes) {
        const durationMs = mode === "stopwatch" ? 0 : minutes * 60000;
        return { mode, durationMs, remainingMs: durationMs, elapsedMs: 0, running: false, lastTickMs: 0, workByDay: {}, workByHour: {} };
    }
    Pomodoro.createTimer = createTimer;
    function tick(timer, nowMs) {
        var _a;
        if (!timer.running)
            return timer;
        const sinceLastTick = Math.max(0, nowMs - timer.lastTickMs);
        const elapsed = timer.mode === "stopwatch" ? sinceLastTick : Math.min(sinceLastTick, timer.remainingMs);
        return Object.assign(Object.assign({}, timer), { remainingMs: timer.mode === "stopwatch" ? 0 : timer.remainingMs - elapsed, elapsedMs: ((_a = timer.elapsedMs) !== null && _a !== void 0 ? _a : timer.durationMs - timer.remainingMs) + elapsed, lastTickMs: nowMs, workByDay: isWorkMode(timer.mode) ? addInterval(timer.workByDay, timer.lastTickMs, timer.lastTickMs + elapsed) : timer.workByDay, workByHour: isWorkMode(timer.mode) ? Pomodoro.addHourlyInterval(timer.workByHour || {}, timer.lastTickMs, timer.lastTickMs + elapsed) : timer.workByHour });
    }
    Pomodoro.tick = tick;
    function toggle(timer, nowMs) {
        if (timer.running)
            return Object.assign(Object.assign({}, tick(timer, nowMs)), { running: false });
        return Object.assign(Object.assign({}, timer), { running: true, lastTickMs: nowMs });
    }
    Pomodoro.toggle = toggle;
    function resize(timer, minutes, nowMs) {
        var _a;
        const current = tick(timer, nowMs);
        if (current.mode === "stopwatch")
            return current;
        const durationMs = minutes * 60000;
        const elapsed = (_a = current.elapsedMs) !== null && _a !== void 0 ? _a : current.durationMs - current.remainingMs;
        return Object.assign(Object.assign({}, current), { durationMs, remainingMs: Math.max(0, durationMs - elapsed) });
    }
    Pomodoro.resize = resize;
    function changeWorkMode(timer, mode, workMinutes, nowMs) {
        var _a;
        if (!isWorkMode(timer.mode))
            return timer;
        const current = tick(timer, nowMs);
        const elapsedMs = (_a = current.elapsedMs) !== null && _a !== void 0 ? _a : current.durationMs - current.remainingMs;
        const durationMs = mode === "stopwatch" ? 0 : workMinutes * 60000;
        return Object.assign(Object.assign({}, current), { mode, elapsedMs, durationMs, remainingMs: Math.max(0, durationMs - elapsedMs) });
    }
    Pomodoro.changeWorkMode = changeWorkMode;
    function finish(timer, history, nowMs, workMinutes, nextMode = "work") {
        const current = tick(timer, nowMs);
        const record = recordSession(history, isWorkMode(current.mode) ? current.workByDay : {});
        return { timer: createTimer(nextMode, workMinutes), history: record.history, minutes: record.minutes };
    }
    Pomodoro.finish = finish;
    function displayMs(timer) {
        return timer.mode === "stopwatch" ? Math.floor(timer.elapsedMs / 1000) * 1000 : timer.remainingMs;
    }
    Pomodoro.displayMs = displayMs;
    function formatTime(remainingMs, vertical = false) {
        const seconds = Math.max(0, Math.ceil(remainingMs / 1000));
        return String(Math.floor(seconds / 60)).padStart(2, "0") + (vertical ? "\n" : ":") + String(seconds % 60).padStart(2, "0");
    }
    Pomodoro.formatTime = formatTime;
})(Pomodoro || (Pomodoro = {}));
