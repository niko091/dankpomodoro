import QtQuick
Text {
    property string name
    property int size
    text: ({
        schedule: "◷", stacks: "▱", hourglass_top: "⌛", target: "◎",
        lightbulb: "✦", event_available: "▣", local_fire_department: "♨",
        close: "×", chevron_left: "‹", chevron_right: "›"
    })[name] || name.slice(0, 1)
    font.pixelSize: size
}
