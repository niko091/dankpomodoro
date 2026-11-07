import QtQuick
Column {
    property string pluginId: ""
    property var pluginService: null
    function loadValue(key, fallback) {
        return pluginService ? pluginService.loadPluginData(pluginId, key, fallback) : fallback;
    }
    function saveValue(key, value) {
        if (pluginService) pluginService.savePluginData(pluginId, key, value);
    }
}
