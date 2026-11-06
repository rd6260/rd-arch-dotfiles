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

        // Open only on the screen the panel was triggered from
        readonly property bool open: ControlPanelService.panelOpen && ControlPanelService.panelScreen === modelData.name
        readonly property bool isFocused: Hyprland.focusedMonitor != null && modelData.name === Hyprland.focusedMonitor.name

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "control_panel"
        exclusiveZone: -1

        color: "transparent"

        // Anchor only to bottom+right so the window doesn't span the whole screen.
        // Clicking anywhere that isn't this window is truly "outside".
        anchors { bottom: true; right: true }

        // Closed → tiny 4×4 hot-zone. Open → sized to content + margins.
        implicitWidth:  panelWindow.open ? panelUi.width  + Layout.sideBarWidth + 32 : 4
        implicitHeight: panelWindow.open ? panelUi.height + Layout.bottomBarHeight + 32 : 4

        // ── Focus grab ────────────────────────────────────────────────────────
        // Bound directly to panelOpen so it activates/deactivates automatically,
        // whether the panel is closed by Escape, outside click, or programmatically.
        HyprlandFocusGrab {
            id: focusGrab
            windows: [panelWindow]
            active: panelWindow.open
            onCleared: ControlPanelService.panelOpen = false
        }

        // ── Hot-zone ──────────────────────────────────────────────────────────
        HoverHandler {
            onHoveredChanged: {
                if (hovered && !ControlPanelService.panelOpen) {
                    ControlPanelService.panelScreen = panelWindow.modelData.name;
                    ControlPanelService.panelOpen = true;
                    // Slight delay so the window has time to resize before grabbing focus
                    focusTimer.start();
                } else if (!hovered && panelWindow.open) {
                    ControlPanelService.panelOpen = false;
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

        // Smooth ease-in-out grow from the bezel corner. No overshoot, and the
        // scale origin is the panel's bezel corner, so it stays attached throughout.
        property real clipProgressX: clipProgress

        Behavior on clipProgress {
            NumberAnimation {
                duration: panelWindow.wasOpen ? 260 : 380
                easing.type: Easing.InOutCubic
            }
        }

        onOpenChanged: {
            panelWindow.wasOpen = !panelWindow.open
            panelWindow.clipProgress = panelWindow.open ? 1.0 : 0.0
        }

        ControlPanelUi {
            id: panelUi
            anchors.bottom: parent.bottom
            anchors.right:  parent.right
            anchors.rightMargin:  Layout.sideBarWidth
            anchors.bottomMargin: Layout.bottomBarHeight
            
            // Non-uniform scale from the bottom-right corner (droplet stretch/squash)
            transform: Scale {
                origin.x: panelUi.width
                origin.y: panelUi.height
                xScale: Math.max(0.001, panelWindow.clipProgressX)
                yScale: Math.max(0.001, panelWindow.clipProgress)
            }
            // Fade only the very beginning; the shape morph does the rest.
            opacity: panelWindow.clipProgress > 0.01 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }
}
