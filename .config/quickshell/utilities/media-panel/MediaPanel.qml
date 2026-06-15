import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "."

/**
 * Bottom-left corner media panel.
 *
 * When CLOSED: a 4×4 px invisible hot-zone sits in the corner.
 *   Moving the cursor there opens the panel.
 *
 * When OPEN: the window grows to exactly the panel's size.
 *   HyprlandFocusGrab is active — any click outside the window
 *   triggers onCleared, which closes the panel.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: panelWindow

        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "media_panel"
        exclusiveZone: -1

        color: "transparent"

        // Anchor only to bottom+left so the window doesn't span the whole screen.
        anchors { bottom: true; left: true }

        // Closed → tiny 4×4 hot-zone. Open → sized to content + margins.
        implicitWidth:  MediaPanelService.panelOpen ? panelUi.width  + 24 : 4
        implicitHeight: MediaPanelService.panelOpen ? panelUi.height + 44 : 4

        // ── Focus grab ────────────────────────────────────────────────────────
        HyprlandFocusGrab {
            id: focusGrab
            windows: [panelWindow]
            active: MediaPanelService.panelOpen
            onCleared: MediaPanelService.panelOpen = false
        }

        // ── Hot-zone ──────────────────────────────────────────────────────────
        HoverHandler {
            enabled: !MediaPanelService.panelOpen
            onHoveredChanged: {
                if (hovered) {
                    MediaPanelService.panelOpen = true;
                    // Slight delay so the window has time to resize before grabbing focus
                    focusTimer.start();
                }
            }
        }

        Timer {
            id: focusTimer
            interval: 30
            repeat: false
            onTriggered: panelUi.forceActiveFocus()
        }

        // ── Panel content ─────────────────────────────────────────────────────
        MediaPanelUi {
            id: panelUi

            // Pin to bottom-left with 12 px margin from the screen edge
            anchors {
                left:  parent.left
                bottom: parent.bottom
                leftMargin:  12
                bottomMargin: 12
            }

            // Slide-up + fade when opening / closing
            opacity: MediaPanelService.panelOpen ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            transform: Translate {
                id: slideY
                y: MediaPanelService.panelOpen ? 0 : 20
                Behavior on y {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
