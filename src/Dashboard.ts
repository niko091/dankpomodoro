namespace Pomodoro {
    export interface SessionStats {
        sessionsByDay: History;
        minutesByDay: History;
        hourlyMs: History;
        trackingSince: string;
    }
    export type DashboardGrouping = Grouping | "weeks" | "weekday";
    export interface DashboardBar extends Bar {
        weekdayIndex?: number;
    }

    export function addHourlyInterval(buckets: History, startMs: number, endMs: number): History {
        const result = { ...buckets };
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

    export function cleanSessionStats(value: unknown): SessionStats {
        const source = value && typeof value === "object" ? value as Record<string, unknown> : {};
        const hourlyMs: History = {};
        if (source.hourlyMs && typeof source.hourlyMs === "object") {
            for (const [hour, ms] of Object.entries(source.hourlyMs)) {
                if (/^(\d|1\d|2[0-3])$/.test(hour) && typeof ms === "number" && Number.isFinite(ms) && ms > 0)
                    hourlyMs[hour] = ms;
            }
        }
        const sessionsByDay = cleanHistory(source.sessionsByDay);
        return {
            sessionsByDay,
            minutesByDay: cleanHistory(source.minutesByDay),
            hourlyMs,
            trackingSince: Object.keys(sessionsByDay).sort()[0] || ""
        };
    }

    export function recordSessionStats(stats: SessionStats, timer: TimerState, minutes: number, nowMs: number): SessionStats {
        if (!isWorkMode(timer.mode) || minutes < 1) return stats;
        const key = dateKey(new Date(nowMs));
        const recorded = recordSession({}, timer.workByDay);
        const minutesByDay = { ...stats.minutesByDay };
        for (const day of Object.keys(recorded.history))
            minutesByDay[day] = (minutesByDay[day] || 0) + recorded.history[day];
        const hourlyMs = { ...stats.hourlyMs };
        for (const hour of Object.keys(timer.workByHour || {}))
            hourlyMs[hour] = (hourlyMs[hour] || 0) + (timer.workByHour || {})[hour];
        return {
            sessionsByDay: { ...stats.sessionsByDay, [key]: (stats.sessionsByDay[key] || 0) + 1 },
            minutesByDay,
            hourlyMs,
            trackingSince: stats.trackingSince || key
        };
    }

    export function dailyGoal(value: unknown): number {
        const minutes = Number(value);
        return value !== undefined && value !== null && value !== "" && Number.isInteger(minutes) && minutes >= 0 && minutes <= 1440 ? minutes : 60;
    }

    function dashboardDate(key: string): Date {
        const parts = key.split("-").map(Number);
        return new Date(parts[0], parts[1] - 1, parts[2], 12);
    }

    function monday(date: Date): Date {
        const result = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
        result.setDate(result.getDate() - (result.getDay() + 6) % 7);
        return result;
    }

    function sumPeriod(history: History, begin: string, end: string): number {
        return Object.keys(history).reduce((total, key) => total + (key >= begin && key <= end ? history[key] : 0), 0);
    }

    export function dashboardSummary(history: History, stats: SessionStats, now: Date, goal: number, streakMinimumMinutes = 1) {
        const today = dateKey(now);
        const start = monday(now);
        const previous = new Date(start);
        previous.setDate(previous.getDate() - 7);
        const previousEnd = new Date(start);
        previousEnd.setDate(previousEnd.getDate() - 1);
        const weekMinutes = sumPeriod(history, dateKey(start), today);
        const previousWeekMinutes = sumPeriod(history, dateKey(previous), dateKey(previousEnd));
        const sessionsThisWeek = sumPeriod(stats.sessionsByDay, dateKey(start), today);
        const previousWeekSessions = sumPeriod(stats.sessionsByDay, dateKey(previous), dateKey(previousEnd));
        const totalSessions = totalMinutes(stats.sessionsByDay);
        const trackedMinutes = totalMinutes(stats.minutesByDay);
        const weekdays = [0, 0, 0, 0, 0, 0, 0];
        let goalsHit = 0;
        for (const day of Object.keys(history)) {
            if (day > today) continue;
            weekdays[dashboardDate(day).getDay()] += history[day];
            if (goal > 0 && day.slice(0, 7) === today.slice(0, 7) && history[day] >= goal) goalsHit++;
        }
        let peakHour: number | null = null;
        let peakMs = 0;
        for (let hour = 0; hour < 24; hour++) {
            if ((stats.hourlyMs[hour] || 0) > peakMs) {
                peakMs = stats.hourlyMs[hour];
                peakHour = hour;
            }
        }
        const bestMinutes = Math.max(...weekdays);
        return {
            totalMinutes: totalMinutes(history),
            totalSessions,
            weekMinutes,
            previousWeekMinutes,
            weekChange: previousWeekMinutes > 0 ? Math.round((weekMinutes - previousWeekMinutes) / previousWeekMinutes * 100) : weekMinutes === 0 ? 0 : null,
            sessionsThisWeek,
            sessionsWeekChange: previousWeekSessions > 0 ? Math.round((sessionsThisWeek - previousWeekSessions) / previousWeekSessions * 100) : null,
            averageMinutes: totalSessions > 0 ? Math.round(trackedMinutes / totalSessions * 10) / 10 : null,
            goalsHit,
            peakHour,
            bestWeekday: bestMinutes > 0 ? weekdays.indexOf(bestMinutes) : null,
            streakDays: streak(history, now, streakMinimumMinutes)
        };
    }

    export function dashboardChart(history: History, now: Date, grouping: DashboardGrouping, page = 0): DashboardBar[] {
        const today = dateKey(now);
        const recorded: History = {};
        for (const day of Object.keys(history)) {
            if (day <= today && history[day] > 0) recorded[day] = history[day];
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
            return chart(recorded, now, "days", 0, Math.round((lastDay - firstDay) / 86400000) + 1);
        }
        if (grouping === "months") {
            const count = (now.getFullYear() - firstDate.getFullYear()) * 12 + now.getMonth() - firstDate.getMonth() + 1;
            return chart(recorded, now, "months", 0, count);
        }
        if (grouping === "years")
            return chart(recorded, now, "years", page, 10);
        const weekly: History = {};
        for (const day of Object.keys(recorded)) {
            const key = dateKey(monday(dashboardDate(day)));
            weekly[key] = (weekly[key] || 0) + recorded[day];
        }
        const end = monday(now);
        const data: DashboardBar[] = [];
        for (const date = monday(firstDate); date <= end; date.setDate(date.getDate() + 7)) {
            const key = dateKey(date);
            data.push({ key, label: String(date.getDate()) + "/" + (date.getMonth() + 1), minutes: weekly[key] || 0, current: key === dateKey(monday(now)), monthIndex: -1 });
        }
        return data;
    }

    export function dashboardHasEarlier(history: History, data: DashboardBar[], grouping: DashboardGrouping): boolean {
        return grouping === "years" && hasEarlier(history, data, "years");
    }
}
