import QtQuick
import "../../theme"

/** Centered icon + message for an empty list. */
Item {
    id: empty
    property string icon: ""
    property string text: ""
    property string hint: ""

    width: parent ? parent.width : 0
    height: visible ? 220 : 0

    Column {
        anchors.centerIn: parent
        spacing: 8
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: empty.icon
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 40 }
            color: Theme.outline
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: empty.text
            color: Theme.on_surface
            font { family: "Google Sans Medium"; pixelSize: 15 }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: empty.hint !== ""
            text: empty.hint
            color: Theme.on_surface_variant
            font { family: "Google Sans"; pixelSize: 12 }
        }
    }
}
