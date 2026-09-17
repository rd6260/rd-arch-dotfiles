pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import "modules"
import qs.theme

/**
 * The primary system status bar rendered across all monitors.
 *
 * Uses a Loader activated via Component.onCompleted so that all child
 * components are instantiated only after the PanelWindow's Wayland surface
 * is fully established. This is necessary for correct rendering on
 * hot-plugged monitors: without the Loader, children bind to the parent
 * geometry before the compositor has sent a configure event, leaving them
 * invisible or mispositioned.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: mainBar

        // --- Screen Mapping ---
        required property var modelData
        screen: modelData

        // --- Layer Shell Configuration ---
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-topbar"

        // --- Geometry & Positioning ---
        anchors {
            top: true
            left: true
            right: true
        }

        // --- Visual Styling ---
        color: "transparent"
        implicitHeight: Layout.topBarHeight

        // --- Content Loader ---
        // Deferred so children initialise after the Wayland surface is ready.
        Loader {
            id: contentLoader
            anchors.fill: parent
            active: false

            sourceComponent: Component {
                Item {
                    anchors.fill: parent

                    // Workspace Switcher
                    Workspaces {
                        id: workspaceModule
                        targetMonitor: mainBar.modelData.name

                        anchors {
                            left: parent.left
                            leftMargin: 15
                            verticalCenter: parent.verticalCenter
                        }
                    }

                    // Calendar / Clock
                    Calendar {
                        id: calendarModule
                        anchors.centerIn: parent
                    }

                    // System Stats
                    SystemStats {
                        id: statusModule
                        panelWindow: mainBar

                        anchors {
                            right: parent.right
                            rightMargin: 15
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // Activate the loader after the surface exists so children see the
        // correct parent geometry from the very first layout pass.
        Component.onCompleted: contentLoader.active = true
    }
}
