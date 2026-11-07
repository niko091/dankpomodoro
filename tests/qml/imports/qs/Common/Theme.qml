pragma Singleton
import QtQuick
QtObject {
    readonly property color primary: "#b6c4ff"
    readonly property color secondary: "#ed9bc6"
    readonly property color info: "#89d6d2"
    readonly property color warning: "#efc080"
    readonly property color surfaceText: "#eeeeee"
    readonly property color surfaceVariantText: "#aaaaaa"
    readonly property color widgetTextColor: "#eeeeee"
    readonly property color surfaceContainerHigh: "#242630"
    readonly property color surfaceContainerHighest: "#333640"
    readonly property int spacingXS: 4
    readonly property int spacingS: 8
    readonly property int spacingM: 12
    readonly property int spacingL: 16
    readonly property int cornerRadius: 12
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeMedium: 14
    readonly property int fontSizeLarge: 18
    readonly property int iconSize: 24
    function barIconSize() { return 24; }
    function barTextSize() { return 14; }
    function hairline() { return 1; }
}
