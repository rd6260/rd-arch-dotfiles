import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import qs.theme

/**
 * A unified system status indicator for Audio (Pipewire) and Power (UPower).
 */
Rectangle {
    id: root

    // --- Window Reference ---
    property var panelWindow: null

    // --- Layout Configuration ---
    implicitWidth: contentLayout.width + 30
    implicitHeight: contentLayout.height + 18
    color: Theme.surface_container
    radius: height / 2

    // --- Audio State Management ---
    readonly property var activeSink: Pipewire.defaultAudioSink
    readonly property bool isMuted: activeSink?.audio?.muted ?? true
    readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0

    /** Ensures Pipewire sink stays reactive to external system changes. */
    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    // --- Tray State Management ---
    property bool isTrayExpanded: false

    Row {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 16

        // --- System Tray Module ---
        Row {
            id: trayModule
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            // Collapsible container for tray items
            Item {
                id: trayContainer
                height: 24
                width: root.isTrayExpanded ? trayContent.width : 0
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }

                Row {
                    id: trayContent
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    spacing: 8

                    Repeater {
                        model: SystemTray.items

                        delegate: Rectangle {
                            id: trayItemRect
                            width: 24
                            height: 24
                            color: "transparent"
                            radius: 4

                            required property var modelData

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.on_surface
                                opacity: trayItemHover.hovered ? 0.1 : 0
                                radius: 4
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: modelData.icon
                                sourceSize: Qt.size(16, 16)
                            }

                            QsMenuAnchor {
                                id: menuAnchor
                                menu: modelData.menu
                                anchor.window: root.panelWindow
                                anchor.item: trayItemRect
                                anchor.edges: Edges.Bottom
                                anchor.gravity: Edges.Bottom
                            }

                            HoverHandler {
                                id: trayItemHover
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onTapped: (eventPoint, button) => {
                                    if (button === Qt.LeftButton) {
                                        modelData.activate();
                                    } else if (button === Qt.RightButton) {
                                        if (modelData.hasMenu) {
                                            menuAnchor.open();
                                        } else {
                                            modelData.secondaryActivate();
                                        }
                                    }
                                }
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            // Toggle Arrow
            Text {
                id: trayToggleIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 16
                }
                color: trayToggleHover.hovered ? Theme.primary : Theme.on_surface_variant
                text: "" // Angle left
                rotation: root.isTrayExpanded ? 180 : 0
                transformOrigin: Item.Center

                Behavior on rotation {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }

                HoverHandler {
                    id: trayToggleHover
                }

                TapHandler {
                    onTapped: root.isTrayExpanded = !root.isTrayExpanded
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // --- Separator ---
        Rectangle {
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Audio Module ---
        Row {
            id: volumeModule
            spacing: 8

            Text {
                id: volumeIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 16
                }
                color: root.isMuted ? Theme.critical : Theme.primary

                text: {
                    if (!root.activeSink?.audio)
                        return ""; // No device
                    if (root.isMuted)
                        return "";           // Muted
                    if (root.volumeLevel >= 0.6)
                        return ""; // High
                    if (root.volumeLevel >= 0.3)
                        return ""; // Mid
                    return "";                              // Low
                }
            }

            Text {
                id: volumeLabel
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.on_surface
                font {
                    family: "Google Sans Medium"
                    pixelSize: 16
                }
                text: root.activeSink?.audio ? Math.round(root.volumeLevel * 100) + "%" : "--%"
            }

            TapHandler {
                onTapped: if (root.activeSink?.audio)
                    root.activeSink.audio.muted = !root.isMuted
                cursorShape: Qt.PointingHandCursor
            }
        }

        // --- Separator ---
        Rectangle {
            visible: batteryModule.isVisible
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Battery Module ---
        Row {
            id: batteryModule
            spacing: 8

            readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool isCharging: !UPower.onBattery

            visible: isVisible

            Text {
                id: batteryIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pixelSize: 16
                }

                color: (batteryModule.isCharging && batteryModule.capacity < 100) || batteryModule.capacity <= 20 ? Theme.critical : Theme.primary

                text: {
                    if (!batteryModule.isVisible)
                        return "";
                    if (batteryModule.isCharging && batteryModule.capacity < 100)
                        return "";

                    if (batteryModule.capacity >= 90)
                        return "󰂂";
                    if (batteryModule.capacity >= 70)
                        return "󰂀";
                    if (batteryModule.capacity >= 50)
                        return "󰁾";
                    if (batteryModule.capacity >= 30)
                        return "󰁼";
                    if (batteryModule.capacity >= 10)
                        return "󰁺";
                    return "󰂃";
                }
            }

            Text {
                id: batteryLabel
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.on_surface
                font {
                    family: "Google Sans Medium"
                    pixelSize: 16
                }
                text: Math.round(batteryModule.capacity) + "%"
            }
        }
    }
}
