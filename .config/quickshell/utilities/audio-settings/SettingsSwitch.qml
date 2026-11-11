import QtQuick
import "../../theme"

/** Material 3 style switch. */
Item {
    id: sw
    property bool checked: false
    property bool busy: false
    signal toggled()

    width: 52; height: 32
    opacity: busy ? 0.55 : 1.0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.primary : Theme.surface_container_highest
        border.width: sw.checked ? 0 : 2
        border.color: Theme.outline
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    Rectangle {
        property real d:sw.checked ? 24 : (hover.hovered ? 20 : 16)
        width: d; height: d; radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? sw.width - d - 4 : 16 - d / 2
        color: sw.checked ? Theme.on_primary : Theme.outline
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on d { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            visible: sw.checked
            text: "󰄬"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
            color: Theme.primary
        }
    }
    HoverHandler { id: hover }
    TapHandler {
        enabled: !sw.busy
        cursorShape: Qt.PointingHandCursor
        onTapped: sw.toggled()
    }
}
