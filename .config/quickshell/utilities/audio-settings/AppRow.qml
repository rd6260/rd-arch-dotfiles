import QtQuick
import Quickshell
import "../../theme"
import "audio.js" as A

/** One application stream: icon, name, what it's playing, volume. */
Rectangle {
    id: row

    required property var node
    property bool input: false

    readonly property string iconSource: {
        for (const name of A.appIconNames(node)) {
            const p = Quickshell.iconPath(name, true);
            if (p) return p;
        }
        return "";
    }
    readonly property string detail: A.appDetail(node)

    implicitHeight: 104
    radius: 20
    color: Theme.surface_container

    Item {
        id: head
        x: 16; y: 14
        width: parent.width - 32
        height: 44

        Rectangle {
            id: iconBox
            width: 44; height: 44; radius: 14
            color: Theme.surface_container_highest

            Image {
                anchors.centerIn: parent
                width: 28; height: 28
                sourceSize: Qt.size(56, 56)
                source: row.iconSource
                visible: row.iconSource !== ""
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: row.iconSource === ""
                text: row.input ? "󰍬" : "󰝚"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                color: Theme.on_surface_variant
            }
        }

        Column {
            anchors {
                left: iconBox.right; leftMargin: 14
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 2
            Text {
                width: parent.width
                text: A.appName(row.node)
                elide: Text.ElideRight
                color: Theme.on_surface
                font { family: "Google Sans Medium"; pixelSize: 15 }
            }
            Text {
                width: parent.width
                visible: row.detail !== ""
                text: row.detail
                elide: Text.ElideRight
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 12 }
            }
        }
    }

    VolumeSlider {
        x: 16
        anchors { top: head.bottom; topMargin: 10 }
        width: parent.width - 32
        input: row.input
        value: row.node?.audio?.volume ?? 0
        muted: row.node?.audio?.muted ?? false
        onMoved: v => {
            const a = row.node?.audio;
            if (!a) return;
            a.volume = v;
            if (a.muted) a.muted = false;
        }
        onMuteToggled: { if (row.node?.audio) row.node.audio.muted = !row.node.audio.muted; }
    }
}
