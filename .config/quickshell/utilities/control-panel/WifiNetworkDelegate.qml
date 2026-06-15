import QtQuick
import "../../theme"

/**
 * A single Wi-Fi network row in the network picker list.
 * Emits connectRequested(ssid) when tapped (if not already connected).
 * The parent ControlPanelUi handles the actual nmcli call.
 */
Item {
    id: root

    required property var network  // object: { ssid, signal, secured, active }

    width: ListView.view ? ListView.view.width : 320
    height: 44

    readonly property bool isActive: network.active === true

    signal connectRequested(string ssid)

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: 8
        color: root.isActive
            ? Theme.secondary_container
            : (hoverHandler.containsMouse ? Theme.surface_container_high : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }

        // Signal strength icon
        Text {
            id: signalIcon
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
            color: root.isActive ? Theme.primary : Theme.on_surface_variant
            text: {
                const s = root.network.signal || 0;
                if (s >= 80) return "󰤨";
                if (s >= 60) return "󰤥";
                if (s >= 40) return "󰤢";
                if (s >= 20) return "󰤟";
                return "󰤯";
            }
        }

        // SSID text
        Text {
            id: ssidLabel
            anchors {
                left: signalIcon.right
                right: lockIcon.visible ? lockIcon.left : parent.right
                leftMargin: 10
                rightMargin: lockIcon.visible ? 6 : 12
                verticalCenter: parent.verticalCenter
            }
            text: root.network.ssid || "(Hidden)"
            color: root.isActive ? Theme.on_secondary_container : Theme.on_surface
            font { family: "Google Sans Medium"; pixelSize: 13 }
            elide: Text.ElideRight
        }

        // Lock icon for secured networks
        Text {
            id: lockIcon
            visible: root.network.secured
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            text: "󰌾"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
            color: root.isActive ? Theme.on_secondary_container : Theme.on_surface_variant
        }

        HoverHandler { id: hoverHandler }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: {
                if (!root.isActive)
                    root.connectRequested(root.network.ssid);
            }
        }
    }
}
