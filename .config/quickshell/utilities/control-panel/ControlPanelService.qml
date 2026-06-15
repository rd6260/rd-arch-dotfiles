pragma Singleton

import QtQuick
import Quickshell.Io

/**
 * Singleton holding all shared state for the control panel.
 * Hostname is fetched once on startup.
 */
QtObject {
    id: root

    // --- Panel visibility ---
    property bool panelOpen: false

    // --- Keep Awake (UI only, backend to be implemented) ---
    property bool keepAwakeEnabled: false

    // --- Night Light ---
    property bool nightLightEnabled: false
    property int nightLightTemp: 3000

    property var _nightLightProc: Process {
        command: ["bash", "-c", "pgrep -x hyprsunset > /dev/null && echo 'true' || echo 'false'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.nightLightEnabled = (text.trim() === "true")
        }
    }

    // --- Hostname ---
    property string hostname: "localhost"

    // --- Fetch hostname once ---
    property var _hostnameProc: Process {
        command: ["bash", "-c", "hostnamectl hostname"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.hostname = text.trim()
        }
    }
}
