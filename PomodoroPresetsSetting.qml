import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "Pomodoro.js" as Logic

Column {
    id: editor
    required property var settingsRoot
    readonly property string pluginId: settingsRoot.pluginId
    property var profiles: []
    readonly property real fieldWidth: Math.max(1, (width - 28 - Theme.spacingS * 3) / 3)
    spacing: Theme.spacingS

    function loadValue() {
        if (!settingsRoot)
            return;
        const legacy = settingsRoot.loadValue("timerPresets", "25/5, 50/10");
        applyProfiles(Logic.Pomodoro.profileRows(settingsRoot.loadValue("timerProfiles", legacy), settingsRoot.loadValue("longBreakDuration", 15)));
    }

    function applyProfiles(next) {
        profiles = next;
        if (!rowsModel)
            return;
        while (rowsModel.count > next.length)
            rowsModel.remove(rowsModel.count - 1);
        for (let index = 0; index < next.length; index++) {
            if (index < rowsModel.count)
                rowsModel.set(index, next[index]);
            else
                rowsModel.append(next[index]);
        }
    }

    function saveProfiles() {
        settingsRoot.saveValue("timerProfiles", profiles);
    }

    function editProfile(index, field, value) {
        const next = Logic.Pomodoro.editProfile(profiles, index, field, value);
        if (next === profiles)
            return;
        applyProfiles(next);
        saveProfiles();
    }

    function addProfile() {
        applyProfiles(Logic.Pomodoro.appendProfile(profiles));
        saveProfiles();
    }

    function removeProfile(index) {
        applyProfiles(Logic.Pomodoro.removeProfile(profiles, index));
        saveProfiles();
    }

    onSettingsRootChanged: loadValue()
    Component.onCompleted: loadValue()

    ListModel {
        id: rowsModel
    }

    Connections {
        target: editor.settingsRoot?.pluginService ?? null
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === editor.pluginId)
                editor.loadValue();
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS
        StyledText {
            width: editor.fieldWidth
            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Work")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        StyledText {
            width: editor.fieldWidth
            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Short break")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
        StyledText {
            width: editor.fieldWidth
            text: I18n.trFor("dankPomodoroTimerPlusPlus", "Long break")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    Repeater {
        model: rowsModel
        Row {
            id: profileRow
            required property int workMinutes
            required property int breakMinutes
            required property int longBreakMinutes
            required property int index
            width: editor.width
            spacing: Theme.spacingS
            DTextField {
                objectName: "profile-work-" + index
                width: editor.fieldWidth
                text: String(profileRow.workMinutes)
                validator: IntValidator {
                    bottom: 1
                    top: 1440
                }
                Accessible.name: I18n.trFor("dankPomodoroTimerPlusPlus", "Work (minutes)")
                onEditingFinished: editor.editProfile(index, "workMinutes", text)
            }
            DTextField {
                objectName: "profile-short-" + index
                width: editor.fieldWidth
                text: String(profileRow.breakMinutes)
                validator: IntValidator {
                    bottom: 1
                    top: 1440
                }
                Accessible.name: I18n.trFor("dankPomodoroTimerPlusPlus", "Short break (minutes)")
                onEditingFinished: editor.editProfile(index, "breakMinutes", text)
            }
            DTextField {
                objectName: "profile-long-" + index
                width: editor.fieldWidth
                text: String(profileRow.longBreakMinutes)
                validator: IntValidator {
                    bottom: 1
                    top: 1440
                }
                Accessible.name: I18n.trFor("dankPomodoroTimerPlusPlus", "Long break (minutes)")
                onEditingFinished: editor.editProfile(index, "longBreakMinutes", text)
            }
            PomodoroIconButton {
                objectName: "profile-remove-" + index
                controlSize: 28
                iconSize: 18
                anchors.verticalCenter: parent.verticalCenter
                iconName: "remove"
                tooltipText: I18n.trFor("dankPomodoroTimerPlusPlus", "Remove timer")
                enabled: editor.profiles.length > 1
                onClicked: editor.removeProfile(index)
            }
        }
    }

    PomodoroIconButton {
        objectName: "addTimerButton"
        controlSize: 32
        iconSize: 20
        iconName: "add"
        tooltipText: I18n.trFor("dankPomodoroTimerPlusPlus", "Add timer")
        onClicked: editor.addProfile()
    }
}
