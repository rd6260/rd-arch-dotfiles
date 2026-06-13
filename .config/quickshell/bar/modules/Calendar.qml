import QtQuick
import qs.services
import qs.theme

/**
 * A reactive clock component that displays the system time in a styled container.
 * Right-click toggles between compact format and extended HH:MM:SS Mon DD/MM/YYYY format.
 */
Rectangle {
    id: root

    // --- State ---
    property bool showExtended: false

    // --- Dimensions ---
    implicitWidth: timeLabel.contentWidth + 20
    implicitHeight: Layout.islandHeight

    // --- Styling ---
    color: Theme.surface_container
    radius: height / 2

    // Smooth width transition when format changes
    Behavior on implicitWidth {
        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
    }

    /**
     * Renders the current time string.
     * - Normal:   from the global Time service (e.g. " H:mm • ddd d ")
     * - Extended: HH:mm:ss Mon dd/MM/yyyy (24-hour) — also from Time service, same clock
     */
    Text {
        id: timeLabel

        anchors.centerIn: parent

        text: root.showExtended ? Time.timeExtended : Time.time
        color: Theme.on_surface_variant

        font {
            family: "Google Sans Medium"
            pointSize: 10
        }
    }

    // Right-click to toggle format
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.showExtended = !root.showExtended
        }
    }
}
