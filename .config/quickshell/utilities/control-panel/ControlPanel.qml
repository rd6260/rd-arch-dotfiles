import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "."

/**
 * Bottom-right corner control panel.
 *
 * When CLOSED: a 4×4 px invisible hot-zone sits in the corner.
 *   Moving the cursor there opens the panel.
 *
 * When OPEN: the window grows to exactly the panel's size.
 *   HyprlandFocusGrab is active — any click outside the window
 *   triggers onCleared, which closes the panel.
 *   This is the same pattern used by the Clipboard component.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: panelWindow

        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "control_panel"
        exclusiveZone: -1

        color: "transparent"

        // Anchor only to bottom+right so the window doesn't span the whole screen.
        // Clicking anywhere that isn't this window is truly "outside".
        anchors { bottom: true; right: true }

        // Closed → tiny 4×4 hot-zone. Open → sized to content + margins.
        implicitWidth:  ControlPanelService.panelOpen ? panelUi.width  + 24 : 4
        implicitHeight: ControlPanelService.panelOpen ? panelUi.height + 44 : 4

        // ── Focus grab ────────────────────────────────────────────────────────
        // Bound directly to panelOpen so it activates/deactivates automatically,
        // whether the panel is closed by Escape, outside click, or programmatically.
        HyprlandFocusGrab {
            id: focusGrab
            windows: [panelWindow]
            active: ControlPanelService.panelOpen
            onCleared: ControlPanelService.panelOpen = false
        }

        // ── Hot-zone ──────────────────────────────────────────────────────────
        // Only active when the panel is closed (window is 4×4).
        HoverHandler {
            enabled: !ControlPanelService.panelOpen
            onHoveredChanged: {
                if (hovered) {
                    ControlPanelService.panelOpen = true;
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
        ControlPanelUi {
            id: panelUi

            // Pin to bottom-right with 12 px margin from the screen edge
            anchors {
                right:  parent.right
                bottom: parent.bottom
                rightMargin:  12
                bottomMargin: 12
            }

            // Slide-up + fade when opening / closing
            opacity: ControlPanelService.panelOpen ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            transform: Translate {
                id: slideY
                y: ControlPanelService.panelOpen ? 0 : 20
                Behavior on y {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
