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

            // Pin to bottom-left exactly so it touches the bezels
            anchors {
                left:  parent.left
                bottom: parent.bottom
                leftMargin: Layout.sideBarWidth
                bottomMargin: Layout.bottomBarHeight
            }

            // "Liquid" scale-up from the corner
            opacity: MediaPanelService.panelOpen ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { 
                    duration: MediaPanelService.panelOpen ? 400 : 250
                    easing.type: Easing.OutCubic 
                }
            }

            transform: Translate {
                y: MediaPanelService.panelOpen ? 0 : 100
                Behavior on y {
                    NumberAnimation { 
                        duration: MediaPanelService.panelOpen ? 500 : 300 
                        easing.type: Easing.OutExpo 
                    }
                }
            }
        }
    }
}
