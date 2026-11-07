pragma Singleton
import QtQuick
QtObject {
    property bool doNotDisturb: false
    function setDoNotDisturb(value) { doNotDisturb = value; }
}
