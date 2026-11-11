import QtQuick
import Quickshell.Services.Pipewire
import "../control-panel"
import "../../theme"
import "audio.js" as A

/**
 * Combined output: one virtual sink that plays to several devices at once.
 * Which devices it plays to is picked with the checkboxes that appear on the
 * output cards above while it's on. This card holds the switch and, when on,
 * the combined volume.
 */
Rectangle {
    id: card

    // Output nodes the combined sink plays to (from the window)
    property var members: []

    readonly property bool active: ControlPanelService.btCombineActive
    readonly property bool busy: ControlPanelService.btCombineBusy
    readonly property var node: ControlPanelService.btCombineNode
    readonly property bool isDefault: active && Pipewire.defaultAudioSink === node
    readonly property bool mixesBtAndWired: members.some(n => A.kind(n) === "bluetooth")
                                         && members.some(n => A.kind(n) !== "bluetooth")

    radius: 20
    color: active ? Theme.secondary_container : Theme.surface_container
    Behavior on color { ColorAnimation { duration: 160 } }
    implicitHeight: head.height + body.height
    clip: true

    readonly property color fg: active ? Theme.on_secondary_container : Theme.on_surface

    // ── Header: title + switch ──────────────────────────────────────────────
    Item {
        id: head
        width: parent.width
        height: 72

        Rectangle {
            id: icon
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44; radius: 22
            color: card.active ? Theme.primary : Theme.surface_container_highest
            Behavior on color { ColorAnimation { duration: 160 } }
            Text {
                anchors.centerIn: parent
                text: "󰓃"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                color: card.active ? Theme.on_primary : Theme.on_surface_variant
            }
        }

        Column {
            anchors {
                left: icon.right; leftMargin: 14
                right: sw.left; rightMargin: 14
                verticalCenter: parent.verticalCenter
            }
            spacing: 2
            Text {
                width: parent.width
                text: "Combined output"
                color: card.fg
                font { family: "Google Sans Medium"; pixelSize: 15 }
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                color: Qt.alpha(card.fg, 0.72)
                font { family: "Google Sans"; pixelSize: 12 }
                text: {
                    if (card.busy) return card.active ? "Turning off…" : "Turning on…";
                    if (!card.active) return "Play the same audio on several devices at once";
                    const n = card.members.length;
                    const s = "Playing to " + n + " device" + (n === 1 ? "" : "s");
                    return card.isDefault ? s : s + "  ·  tap to use as output";
                }
            }
        }

        SettingsSwitch {
            id: sw
            anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
            checked: card.active || (card.busy && !card.active)
            busy: card.busy
            onToggled: ControlPanelService.setBtCombine(!card.active)
        }

        // On but something else is the default: tap the title area to switch back
        Item {
            anchors { left: parent.left; right: sw.left; top: parent.top; bottom: parent.bottom }
            HoverHandler { cursorShape: card.active && !card.isDefault ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler {
                onTapped: if (card.node && !card.isDefault) Pipewire.preferredDefaultAudioSink = card.node
            }
        }
    }

    // ── Body (when on): combined volume + sync warning ──────────────────────
    Item {
        id: body
        anchors.top: head.bottom
        width: parent.width
        height: card.active ? bodyCol.implicitHeight : 0
        clip: true
        visible: height > 0
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Column {
            id: bodyCol
            width: parent.width
            bottomPadding: 14
            spacing: 6

            VolumeSlider {
                x: 16
                width: parent.width - 32
                value: card.node?.audio?.volume ?? 0
                muted: card.node?.audio?.muted ?? false
                trackColor: Qt.alpha(Theme.on_secondary_container, 0.14)
                onMoved: v => {
                    const a = card.node?.audio;
                    if (!a) return;
                    a.volume = v;
                    if (a.muted) a.muted = false;
                }
                onMuteToggled: { if (card.node?.audio) card.node.audio.muted = !card.node.audio.muted; }
            }

            // Bluetooth vs wired latency warning
            Text {
                visible: card.mixesBtAndWired
                x: 20
                width: parent.width - 40
                wrapMode: Text.WordWrap
                text: "󰀦  Bluetooth adds a delay that wired outputs don't have, so they may sound out of sync."
                color: Qt.alpha(card.fg, 0.72)
                font { family: "Google Sans"; pixelSize: 11 }
            }
        }
    }
}
