import QtQuick
import qs.Common
import qs.DCommon.Widgets

Rectangle {
    id: card
    property string title: ""
    property string value: ""
    property string detail: ""
    property bool comparisonBadge: false
    property var comparisonChange: null
    property string iconName: ""
    property color accent: Theme.primary
    property bool compact: false
    height: compact ? 80 : Math.max(124, metricColumn.implicitHeight + 40)
    radius: Theme.cornerRadius
    color: compact ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    border.width: compact ? 0 : 1
    border.color: Qt.alpha(Theme.surfaceText, 0.08)
    Accessible.role: Accessible.StaticText
    Accessible.name: title + ": " + value + (detail ? ". " + detail : "")

    Rectangle {
        id: iconTile
        objectName: "statIcon"
        x: 16
        y: card.compact ? (parent.height - height) / 2 : 20
        width: card.compact ? 36 : 44
        height: width
        radius: Theme.cornerRadius
        color: Qt.alpha(card.accent, 0.16)
        DIcon {
            anchors.centerIn: parent
            name: card.iconName
            size: card.compact ? 20 : 24
            color: card.accent
        }
    }
    Column {
        id: metricColumn
        x: iconTile.x + iconTile.width + 12
        y: card.compact ? (card.height - implicitHeight) / 2 : iconTile.y
        width: parent.width - x - 16
        spacing: 4
        StyledText {
            id: valueText
            objectName: "statValue"
            width: parent.width
            text: card.compact ? card.title : card.value
            color: card.compact ? Theme.surfaceVariantText : Theme.surfaceText
            font.pixelSize: card.compact ? Theme.fontSizeSmall : Theme.fontSizeXXLarge
            font.weight: card.compact ? Font.Normal : Font.DemiBold
            elide: Text.ElideRight
        }
        StyledText {
            id: titleText
            objectName: "statTitle"
            width: parent.width
            text: card.compact ? card.value : card.title
            color: Theme.surfaceText
            font.pixelSize: card.compact ? Theme.fontSizeXLarge : Theme.fontSizeMedium
            font.weight: card.compact ? Font.Medium : Font.Normal
            wrapMode: card.compact ? Text.NoWrap : Text.WordWrap
            elide: Text.ElideRight
        }
        Rectangle {
            objectName: "statComparison"
            readonly property string text: card.detail
            readonly property color comparisonColor: card.comparisonChange === null ? Theme.surfaceVariantText : card.comparisonChange < 0 ? Theme.error : Theme.success
            width: card.comparisonBadge ? Math.min(parent.width, comparisonText.implicitWidth + 16) : parent.width
            height: comparisonText.implicitHeight + (card.comparisonBadge ? 8 : 0)
            visible: card.detail.length > 0
            radius: height / 2
            color: !card.comparisonBadge ? "transparent" : card.comparisonChange === null ? Theme.surfaceContainerHighest : Qt.alpha(comparisonColor, 0.16)
            StyledText {
                id: comparisonText
                anchors.fill: parent
                anchors.leftMargin: card.comparisonBadge ? 8 : 0
                anchors.rightMargin: card.comparisonBadge ? 8 : 0
                verticalAlignment: Text.AlignVCenter
                text: (card.comparisonBadge && card.comparisonChange !== null ? (card.comparisonChange < 0 ? "↓ " : "↑ ") : "") + card.detail
                color: card.comparisonBadge ? parent.comparisonColor : card.accent
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }
    }
}
