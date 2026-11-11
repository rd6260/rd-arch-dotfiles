import QtQuick
import "../../theme"

/** Mute button + volume track + percentage. Emits changes; the owner applies them. */
Item {
    id: s

    property real value: 0
    property bool muted: false
    property bool input: false
    property color accent: Theme.primary
    // Track colour behind the fill (lets cards on coloured backgrounds contrast)
    property color trackColor: Theme.surface_container_highest

    signal moved(real v)
    signal muteToggled()

    implicitHeight: 32

    readonly property real frac: Math.max(0, Math.min(1, value))
    readonly property color fillColor: muted ? Theme.outline : accent

    // Mute toggle
    Item {
        id: muteBtn
        width: 32; height: 32
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: muteHover.hovered ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        Text {
            anchors.centerIn: parent
            text: s.input ? (s.muted ? "󰍭" : "󰍬")
                : s.muted ? "󰖁" : s.value >= 0.6 ? "󰕾" : s.value >= 0.3 ? "󰖀" : "󰕿"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            color: s.muted ? Theme.on_surface_variant : s.accent
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        HoverHandler { id: muteHover }
        TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: s.muteToggled() }
    }

    // Track
    Item {
        id: track
        height: 24
        anchors {
            left: muteBtn.right; leftMargin: 10
            right: pct.left; rightMargin: 12
            verticalCenter: parent.verticalCenter
        }

        readonly property real handleX: width * s.frac

        // Inactive part (right of the handle)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.min(parent.width - 4, track.handleX + 6)
            width: parent.width - x
            height: 10; radius: 5
            color: s.trackColor
        }
        // Active part (left of the handle)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, track.handleX - 6)
            visible: width > 0
            height: 10; radius: 5
            color: s.fillColor
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        // Handle
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, track.handleX - width / 2))
            width: area.pressed ? 3 : 4
            height: 24; radius: 2
            color: s.fillColor
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        MouseArea {
            id: area
            anchors { fill: parent; topMargin: -4; bottomMargin: -4 }
            cursorShape: Qt.PointingHandCursor
            preventStealing: true   // don't let the page Flickable take horizontal drags

            function apply(x) { s.moved(Math.max(0, Math.min(1, x / width))); }
            onPressed: m => apply(m.x)
            onPositionChanged: m => { if (pressed) apply(m.x); }
        }
    }

    Text {
        id: pct
        width: 38
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        horizontalAlignment: Text.AlignRight
        text: Math.round(s.value * 100) + "%"
        color: s.muted ? Theme.on_surface_variant : Theme.on_surface
        font { family: "Google Sans Medium"; pixelSize: 12 }
    }
}
