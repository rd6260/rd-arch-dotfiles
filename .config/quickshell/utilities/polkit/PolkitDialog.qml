import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import QtQuick
import "../../theme"

/**
 * PolicyKit authentication overlay.
 *
 * PolkitAgent registers itself on the session bus and sets isActive=true
 * when a privilege escalation is requested. The dialog appears on the
 * currently focused monitor, grabs exclusive keyboard focus, and proxies
 * all interaction through the AuthFlow object (agent.flow).
 */
Scope {
    id: root

    // ── Native polkit agent ──────────────────────────────────────────────────
    PolkitAgent {
        id: polkitAgent
    }

    // ── One overlay per screen, shown only on the focused monitor ────────────
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "polkit_dialog"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusiveZone: -1
            color: "transparent"

            anchors { left: true; right: true; top: true; bottom: true }

            readonly property bool isFocusedMonitor:
                Hyprland.focusedMonitor != null &&
                modelData.name === Hyprland.focusedMonitor.name

            visible: polkitAgent.isActive && isFocusedMonitor

            onVisibleChanged: {
                if (visible) focusTimer.start();
            }

            Timer {
                id: focusTimer
                interval: 30
                repeat: false
                onTriggered: dialogUi.focusPassword()
            }

            HyprlandFocusGrab {
                windows: [win]
                active: win.visible
                onCleared: {
                    if (polkitAgent.flow)
                        polkitAgent.flow.cancelAuthenticationRequest();
                }
            }

            // Scrim backdrop
            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
                opacity: win.visible ? 0.45 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (polkitAgent.flow)
                            polkitAgent.flow.cancelAuthenticationRequest();
                    }
                }
            }

            // Dialog card — spring-pop entrance
            PolkitDialogUi {
                id: dialogUi
                anchors.centerIn: parent
                flow: polkitAgent.flow

                scale:   win.visible ? 1.0 : 0.88
                opacity: win.visible ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
