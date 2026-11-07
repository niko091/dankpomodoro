pragma Singleton
import QtQuick

// DMS's plugin translation API; catalogs are supplied by the test host.
QtObject {
    property var pluginTranslations: ({})
    function registerPluginTranslations(pluginId, table) {
        const next = Object.assign({}, pluginTranslations);
        next[pluginId] = table;
        pluginTranslations = next;
    }
    function unregisterPluginTranslations(pluginId) {
        const next = Object.assign({}, pluginTranslations);
        delete next[pluginId];
        pluginTranslations = next;
    }
    function trFor(pluginId, term) {
        const table = pluginTranslations[pluginId];
        return table && table[term] && table[term][term] ? table[term][term] : term;
    }
}
