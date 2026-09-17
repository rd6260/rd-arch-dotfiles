import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "."
import "../../theme"

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: panelWindow

        required property var modelData
        screen: modelData

        readonly property bool isFocused: Hyprland.focusedMonitor != null && modelData.name === Hyprland.focusedMonitor.name

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "app_launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusiveZone: -1

        color: "transparent"

        // Cover the screen by setting all anchors to true
        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        property real clipProgress: 0.0

        visible: isFocused && (AppLauncherService.panelOpen || clipProgress > 0.01)

        Behavior on clipProgress {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Connections {
            target: AppLauncherService
            function onPanelOpenChanged() {
                if (!panelWindow.isFocused) return;
                panelWindow.clipProgress = AppLauncherService.panelOpen ? 1.0 : 0.0;
                if (AppLauncherService.panelOpen) {
                    focusTimer.start();
                }
            }
        }

        Timer {
            id: focusTimer
            interval: 30
            repeat: false
            onTriggered: {
                launcherUi.focusSearch();
            }
        }

        // Focus grab to handle keyboard focus and window clearing
        HyprlandFocusGrab {
            id: focusGrab
            windows: [panelWindow]
            active: isFocused && AppLauncherService.panelOpen
            onCleared: AppLauncherService.panelOpen = false
        }

        // Background click detector and scrim overlay to close launcher when clicking outside launcherUi
        MouseArea {
            anchors.fill: parent
            onClicked: AppLauncherService.panelOpen = false

            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
                opacity: 0.18 * panelWindow.clipProgress
            }
        }

        AppLauncherUi {
            id: launcherUi
            anchors.centerIn: parent
            scale: panelWindow.clipProgress
            opacity: panelWindow.clipProgress
        }
    }
}
