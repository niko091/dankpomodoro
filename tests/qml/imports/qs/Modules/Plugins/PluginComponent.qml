import QtQuick
Item {
    id: root
    property string layerNamespacePlugin: "plugin"
    property var pluginData: ({})
    property var pluginService: null
    property string pluginId: ""
    property real barThickness: 48
    property int iconSize: 24
    property int textSize: 14
    property var barConfig: null
    property real dpr: 1
    property real popoutWidth: 400
    property var parentScreen: null
    property bool popoutClosed: false
    function closePopout() { popoutClosed = true; }
    property Component horizontalBarPill
    property Component verticalBarPill
    property Component popoutContent
    function loadPluginData() {
        pluginData = pluginService ? pluginService.settings[pluginId] || {} : {};
    }
    onPluginServiceChanged: loadPluginData()
    onPluginIdChanged: loadPluginData()
    Component.onCompleted: loadPluginData()
    Connections {
        target: root.pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId) root.loadPluginData();
        }
    }
}
