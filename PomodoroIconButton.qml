import QtQuick
import qs.Common
import qs.DCommon.Widgets

DButton {
    property int controlSize: 64
    width: controlSize
    buttonHeight: controlSize
    minimumWidth: 0
    maximumWidth: width
    iconSize: 24
    textColor: Theme.surfaceText
    variant: "text"
    Accessible.name: tooltipText
}
