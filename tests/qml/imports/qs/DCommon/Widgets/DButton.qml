import QtQuick
import QtQuick.Controls
Button {
    property string iconName
    property string tooltipText
    property bool wrapText
    property real maximumWidth
    property real minimumWidth
    property string variant
    property int iconSize
    property color textColor
    property int buttonHeight: 48
    font.pixelSize: 12
}
