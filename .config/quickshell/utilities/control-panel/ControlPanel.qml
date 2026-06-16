import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "."
import "../../theme"

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
        implicitWidth:  ControlPanelService.panelOpen ? panelUi.width  + Layout.sideBarWidth + 32 : 4
        implicitHeight: ControlPanelService.panelOpen ? panelUi.height + Layout.bottomBarHeight + 32 : 4

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
        property real clipProgress: 0.0
        property bool wasOpen: false

        Behavior on clipProgress {
            NumberAnimation {
                duration: panelWindow.wasOpen ? 200 : 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: panelWindow.wasOpen
                    ? [0.3,  0.0,  0.8,  0.15, 1.0, 1.0]
                    : [0.38, 1.21, 0.22, 1.0,  1.0, 1.0]
            }
        }

        Connections {
            target: ControlPanelService
            function onPanelOpenChanged() {
                panelWindow.wasOpen = !ControlPanelService.panelOpen
                panelWindow.clipProgress = ControlPanelService.panelOpen ? 1.0 : 0.0
            }
        }

        ControlPanelUi {
            id: panelUi
            anchors.bottom: parent.bottom
            anchors.right:  parent.right
            anchors.rightMargin:  Layout.sideBarWidth
            anchors.bottomMargin: Layout.bottomBarHeight
            
            transformOrigin: Item.BottomRight
            scale: panelWindow.clipProgress
            // Apply a slight opacity fade to smooth the very beginning of the spring, but 
            // the main morphing effect is the scale spring.
            opacity: panelWindow.clipProgress > 0 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }
}
