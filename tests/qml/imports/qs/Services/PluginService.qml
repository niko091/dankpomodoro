pragma Singleton
import QtQuick
QtObject {
    property var globalVars: ({})
    property var states: ({})
    property var settings: ({})
    signal pluginDataChanged(string pluginId)
    signal pluginStateChanged(string pluginId)
    function setGlobalVar(pid, key, value) {
        const next = Object.assign({}, globalVars);
        next[pid] = Object.assign({}, next[pid] || {});
        next[pid][key] = value;
        globalVars = next;
    }
    function loadPluginState(pid, key, fallback) {
        return states[pid + "/" + key] ?? fallback;
    }
    function savePluginState(pid, key, value) {
        const next = Object.assign({}, states);
        next[pid + "/" + key] = value;
        states = next;
        pluginStateChanged(pid);
    }
    function loadPluginData(pid, key, fallback) {
        return settings[pid]?.[key] ?? fallback;
    }
    function savePluginData(pid, key, value) {
        const next = Object.assign({}, settings);
        next[pid] = Object.assign({}, next[pid] || {});
        next[pid][key] = value;
        settings = next;
        pluginDataChanged(pid);
    }
}
