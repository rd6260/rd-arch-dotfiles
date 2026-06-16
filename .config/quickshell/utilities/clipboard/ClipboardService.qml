pragma Singleton

import QtQuick
import Quickshell.Io

Item {
    id: root

    // --- Panel visibility ---
    property bool panelOpen: false

    IpcHandler {
        target: "clipMenu"
        function toggle() {
            root.panelOpen = !root.panelOpen;
        }
    }
}
