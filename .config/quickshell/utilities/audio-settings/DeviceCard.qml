import QtQuick
import Quickshell.Bluetooth
import "../../theme"
import "audio.js" as A

/**
 * One output or input device with its volume.
 *
 * Normal mode: the highlighted card is the default device; tapping the top
 * row of another card makes it the default.
 * Checkable mode (combined output on): a checkbox appears on the right and
 * the highlighted cards are the ones the combined output plays to.
 */
Rectangle {
    id: card

    required property var node
    property bool input: false
    property bool isDefault: false
    signal selected()

    property bool checkable: false
    property bool checked: false
    property bool checkLocked: false
    signal checkToggled()

    readonly property bool highlighted: checkable ? checked : isDefault
    readonly property bool tappable: checkable ? !checkLocked : !isDefault

    readonly property string mac: A.btMac(node)
    readonly property var btDevice: mac !== ""
        ? (Bluetooth.devices.values.find(d => d.address.toUpperCase() === mac) ?? null) : null
    readonly property string subtitle: {
        let s = A.kindLabel(node, input);
        if (btDevice && btDevice.batteryAvailable)
            s += "  ·  " + Math.round(btDevice.battery * 100) + "% battery";
        return s;
    }
    readonly property color fg: highlighted ? Theme.on_secondary_container : Theme.on_surface

    implicitHeight: 112
    radius: 20
    color: highlighted ? Theme.secondary_container
         : headHover.hovered && tappable ? Theme.surface_container_high : Theme.surface_container
    Behavior on color { ColorAnimation { duration: 160 } }

    // ── Top row: tap to make default / toggle membership ─────────────────
    Item {
        id: head
        x: 16; y: 14
        width: parent.width - 32
        height: 44

        Rectangle {
            id: icon
            width: 44; height: 44; radius: 22
            color: card.highlighted ? Theme.primary : Theme.surface_container_highest
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: A.icon(card.node, card.input)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                color: card.highlighted ? Theme.on_primary : Theme.on_surface_variant
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        Column {
            anchors {
                left: icon.right; leftMargin: 14
                right: checkSlot.left; rightMargin: checkSlot.width > 0 ? 12 : 0
                verticalCenter: parent.verticalCenter
            }
            spacing: 2
            Text {
                width: parent.width
                text: A.label(card.node)
                elide: Text.ElideRight
                color: card.fg
                font { family: "Google Sans Medium"; pixelSize: 15 }
            }
            Text {
                width: parent.width
                text: card.subtitle
                elide: Text.ElideRight
                color: Qt.alpha(card.fg, 0.72)
                font { family: "Google Sans"; pixelSize: 12 }
            }
        }

        // Checkbox, only in checkable mode (slides in from the right edge)
        Item {
            id: checkSlot
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: card.checkable ? 22 : 0
            height: 22
            clip: true
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 22; height: 22; radius: 6
                anchors.right: parent.right
                color: card.checked ? Theme.primary : "transparent"
                border.width: card.checked ? 0 : 2
                border.color: card.highlighted ? Theme.on_secondary_container : Theme.outline
                opacity: card.checkLocked ? 0.5 : 1
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    visible: card.checked
                    text: "󰄬"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                    color: Theme.on_primary
                }
            }
        }

        HoverHandler { id: headHover; cursorShape: card.tappable ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler {
            onTapped: {
                if (!card.tappable) return;
                if (card.checkable) card.checkToggled();
                else card.selected();
            }
        }
    }

    VolumeSlider {
        x: 16
        anchors { top: head.bottom; topMargin: 10 }
        width: parent.width - 32
        input: card.input
        value: card.node?.audio?.volume ?? 0
        muted: card.node?.audio?.muted ?? false
        trackColor: card.highlighted ? Qt.alpha(Theme.on_secondary_container, 0.14) : Theme.surface_container_highest
        onMoved: v => {
            const a = card.node?.audio;
            if (!a) return;
            a.volume = v;
            if (a.muted) a.muted = false;
        }
        onMuteToggled: { if (card.node?.audio) card.node.audio.muted = !card.node.audio.muted; }
    }
}
