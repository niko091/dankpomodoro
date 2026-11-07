import QtQuick
import qs.Common
import qs.DCommon.Widgets

Rectangle {
    id: card
    property string title: ""
    property string value: ""
    property string detail: ""
    property string iconName: ""
    property color accent: Theme.primary
    property bool compact: false
    height: compact ? 80 : 124
    radius: Theme.cornerRadius
    color: compact ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    border.width: compact ? 0 : 1
    border.color: Qt.alpha(Theme.surfaceText, 0.08)
    Accessible.role: Accessible.StaticText
    Accessible.name: title + ": " + value + (detail ? ". " + detail : "")

    Rectangle {
        id: iconTile
        x: 16
        y: card.compact ? (parent.height - height) / 2 : 20
        width: card.compact ? 36 : 44
        height: width
        radius: 12
        color: Qt.alpha(card.accent, 0.16)
        DIcon {
            anchors.centerIn: parent
            name: card.iconName
            size: card.compact ? 20 : 24
            color: card.accent
        }
    }
    Column {
        x: iconTile.x + iconTile.width + 12
        width: parent.width - x - 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        StyledText {
            width: parent.width
            text: card.compact ? card.title : card.value
            color: card.compact ? Theme.surfaceVariantText : Theme.surfaceText
            font.pixelSize: card.compact ? Theme.fontSizeSmall : 26
            font.weight: card.compact ? Font.Normal : Font.DemiBold
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            text: card.compact ? card.value : card.title
            color: Theme.surfaceText
            font.pixelSize: card.compact ? 20 : Theme.fontSizeMedium
            font.weight: card.compact ? Font.Medium : Font.Normal
            wrapMode: card.compact ? Text.NoWrap : Text.WordWrap
            elide: Text.ElideRight
        }
        StyledText {
            width: parent.width
            visible: card.detail.length > 0
            text: card.detail
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }
}
