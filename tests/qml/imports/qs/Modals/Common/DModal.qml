import QtQuick

// DMS surface API substitute; content is rendered by the real Qt Quick engine.
Item {
    id: modal
    property Component content
    property real modalWidth: 400
    property real modalHeight: 300
    property var targetScreen
    property string positioning: "center"
    property bool shouldBeVisible: false
    property real screenWidth: 1920
    property real screenHeight: 1080
    property alias contentLoader: loader
    signal backgroundClicked()
    signal dialogClosed()
    width: modalWidth
    height: modalHeight
    visible: shouldBeVisible
    z: 100
    function open() { shouldBeVisible = true; }
    function close() { shouldBeVisible = false; dialogClosed(); }
    Rectangle {
        anchors.fill: parent
        color: "#17181d"
        z: -1
    }
    Loader {
        id: loader
        anchors.fill: parent
        active: modal.shouldBeVisible
        sourceComponent: modal.content
    }
}
