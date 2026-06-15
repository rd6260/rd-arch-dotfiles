import QtQuick
import Quickshell.Services.Pipewire
import "../../theme"

/**
 * A single audio device (sink or source) row in the device picker list.
 * Tapping sets the device as the preferred default via Pipewire.
 */
Item {
    id: root

    required property var device
    required property var activeDevice
    property bool isSink: true

    width: ListView.view ? ListView.view.width : 320
    height: 44

    readonly property bool isActive: {
        if (!activeDevice || !device) return false;
        return activeDevice.name === device.name;
    }

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

        // Active indicator dot
        Rectangle {
            id: activeDot
            width: 6; height: 6; radius: 3
            color: Theme.primary
            anchors {
                left: parent.left
                leftMargin: 12
                verticalCenter: parent.verticalCenter
            }
            opacity: root.isActive ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // Device name — shifts right when active dot is visible
        Text {
            id: deviceLabel
            // Use x-based positioning so we can animate the indent
            x: root.isActive ? 26 : 12
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            width: parent.width - x - 12
            text: root.device?.description || root.device?.name || "Unknown Device"
            color: root.isActive ? Theme.on_secondary_container : Theme.on_surface
            font { family: "Google Sans"; pixelSize: 12 }
            elide: Text.ElideRight

            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        HoverHandler { id: hoverHandler }

        TapHandler {
            cursorShape: Qt.PointingHandCursor
            onTapped: {
                if (!root.isActive && root.device) {
                    if (root.isSink) {
                        Pipewire.preferredDefaultAudioSink = root.device;
                    } else {
                        Pipewire.preferredDefaultAudioSource = root.device;
                    }
                }
            }
        }
    }
}
