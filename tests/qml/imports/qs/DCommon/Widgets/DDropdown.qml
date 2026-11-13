import QtQuick
import QtQuick.Controls

// Qt popup substitute for DMS's Wayland dropdown surface.
Item {
    id: root
    property var transientSurfaceTracker: null
    property bool showTrigger: true
    property Item popupAnchorItem
    property Item focusReturnTarget
    property bool alignPopupRight: false
    property int dropdownWidth: 160
    property string currentValue: ""
    property var options: []
    property var optionValues: []
    readonly property bool menuOpen: menu.visible
    property alias menuContent: menu.contentItem
    signal valueChanged(string value)
    function openDropdownMenu() {
        if (menu.visible)
            menu.close();
        else
            menu.open();
    }
    function closeDropdownMenu() {
        menu.close();
    }

    Popup {
        id: menu
        parent: root.popupAnchorItem
        x: root.alignPopupRight ? parent.width - width : 0
        y: parent.height + 4
        width: root.dropdownWidth
        height: Math.min(root.options.length, 8) * 40 + padding * 2
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            if (root.focusReturnTarget)
                root.focusReturnTarget.forceActiveFocus();
        }
        contentItem: ListView {
            clip: true
            model: root.optionValues.length > 0 ? root.optionValues : root.options
            delegate: ItemDelegate {
                required property string modelData
                objectName: "preset-" + modelData
                width: ListView.view.width
                height: 40
                text: root.optionValues.length > 0 ? root.options[root.optionValues.indexOf(modelData)] : modelData
                highlighted: modelData === root.currentValue
                onClicked: {
                    root.currentValue = modelData;
                    root.valueChanged(modelData);
                    menu.close();
                }
            }
        }
    }
}
