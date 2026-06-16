import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "."
import "../../theme"

/**
 * Bottom-middle clipboard panel.
 *
 * When CLOSED: a 400×4 px invisible hot-zone sits in the bottom middle.
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
        WlrLayershell.namespace: "clipboard_overlay"
        exclusiveZone: -1

        color: "transparent"

        // Anchors to bottom, defaulting to center horizontally.
        anchors { bottom: true }

        // Static sizing to prevent Hyprland 0x0 centering bugs.
        // We use an explicit mask so the visually clipped area doesn't swallow clicks.
        implicitWidth:  panelUi.width
        implicitHeight: panelUi.height + Layout.bottomBarHeight

        mask: Region {
            item: clipItem
        }

        // ── Focus grab ────────────────────────────────────────────────────────
        HyprlandFocusGrab {
            id: focusGrab
            windows: [panelWindow]
            active: ClipboardService.panelOpen
            onCleared: ClipboardService.panelOpen = false
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
            target: ClipboardService
            function onPanelOpenChanged() {
                panelWindow.wasOpen = !ClipboardService.panelOpen
                panelWindow.clipProgress = ClipboardService.panelOpen ? 1.0 : 0.0
            }
        }

        Item {
            id: clipItem
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: Layout.bottomBarHeight
            
            width: panelUi.width
            height: panelUi.height * panelWindow.clipProgress
            clip: true

            ClipboardUi {
                id: panelUi
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
