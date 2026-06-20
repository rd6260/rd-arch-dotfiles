import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../../theme"
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
        implicitWidth:  MediaPanelService.panelOpen ? panelUi.width  + Layout.sideBarWidth + 32 : 4
        implicitHeight: MediaPanelService.panelOpen ? panelUi.height + Layout.bottomBarHeight + 32 : 4

        // ── Focus grab ────────────────────────────────────────────────────────
        HyprlandFocusGrab {
            id: focusGrab
            windows: [panelWindow]
            active: MediaPanelService.panelOpen
            onCleared: MediaPanelService.panelOpen = false
        }

        // ── Hot-zone ──────────────────────────────────────────────────────────
        HoverHandler {
            onHoveredChanged: {
                if (hovered && !MediaPanelService.panelOpen) {
                    MediaPanelService.panelOpen = true;
                    // Slight delay so the window has time to resize before grabbing focus
                    focusTimer.start();
                } else if (!hovered && MediaPanelService.panelOpen) {
                    MediaPanelService.panelOpen = false;
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
        // Spring bezier matches caelestia expressiveDefaultSpatial.
        // wasOpen tracks direction: false=opening (spring), true=closing (fast).
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
            target: MediaPanelService
            function onPanelOpenChanged() {
                panelWindow.wasOpen = !MediaPanelService.panelOpen
                panelWindow.clipProgress = MediaPanelService.panelOpen ? 1.0 : 0.0
            }
        }

        MediaPanelUi {
            id: panelUi
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.leftMargin:   Layout.sideBarWidth
            anchors.bottomMargin: Layout.bottomBarHeight
            
            transformOrigin: Item.BottomLeft
            scale: panelWindow.clipProgress
            opacity: panelWindow.clipProgress > 0 ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 100 } }
        }
    }
}
