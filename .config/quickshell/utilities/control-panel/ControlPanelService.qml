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

    // --- Audio Visualizer ---
    property bool visualizerEnabled: false
    property var cavaData: []

    property var _cavaProc: Process {
        id: cavaProc
        running: root.visualizerEnabled

        command: ["sh", "-c", `
            cava -p /dev/stdin <<EOF
[general]
bars = 24
framerate = 60
autosens = 1

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59

[smoothing]
monstercat = 1.5
waves = 0
gravity = 100
noise_reduction = 0.20
EOF
        `]

        stdout: SplitParser {
            onRead: data => {
                let newPoints = data.split(";")
                    .map(p => parseFloat(p.trim()) / 1000)
                    .filter(p => !isNaN(p))

                let smoothFactor = 0.3

                if (root.cavaData.length === 0 ||
                    root.cavaData.length !== newPoints.length) {
                    root.cavaData = newPoints
                } else {
                    let smoothed = []
                    for (let i = 0; i < newPoints.length; i++) {
                        let oldVal = root.cavaData[i]
                        let newVal = newPoints[i]
                        smoothed.push(oldVal + (newVal - oldVal) * smoothFactor)
                    }
                    root.cavaData = smoothed
                }
            }
        }
    }

    // --- Tailscale State ---
    property bool tailscaleEnabled: false

    property var _tailscaleStateCheck: Process {
        id: tsStateCheck
        command: ["bash", "-c", "tailscale status &>/dev/null && echo \"Up\" || echo \"Down\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.tailscaleEnabled = text.trim() === "Up";
            }
        }
    }

    property var _tailscaleCmd: Process {
        id: tsCmd
        property bool targetState: true
        command: ["bash", "-c", "echo dummy"]
        running: false
        onRunningChanged: {
            if (!running) {
                tsStateCheck.running = false;
                tsStateCheck.running = true;
            }
        }
    }

    function toggleTailscale() {
        let newState = !tailscaleEnabled;
        tsCmd.command = ["bash", "-c", newState ? "tailscale up" : "tailscale down"];
        tsCmd.targetState = newState;
        tsCmd.running = false;
        tsCmd.running = true;
        tailscaleEnabled = newState;
    }

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

    // --- Screen Recording ---
    property bool screenRecordingActive: false
    property bool screenRecordingPaused: false
    property int screenRecordingElapsedSeconds: 0
    property string screenRecordingElapsedText: "00:00"

    property var _screenRecordTimer: Timer {
        id: screenRecordTimer
        interval: 1000
        repeat: true
        running: root.screenRecordingActive && !root.screenRecordingPaused
        onTriggered: {
            root.screenRecordingElapsedSeconds += 1;
            let m = Math.floor(root.screenRecordingElapsedSeconds / 60);
            let s = root.screenRecordingElapsedSeconds % 60;
            root.screenRecordingElapsedText = (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
        }
    }

    property var _setupRecDir: Process {
        command: ["bash", "-c", "mkdir -p $HOME/Videos/screen-recording"]
        running: false
        onRunningChanged: {
            if (!running && _startRecFlag) {
                root.screenRecordingElapsedSeconds = 0;
                root.screenRecordingElapsedText = "00:00";
                root.screenRecordingPaused = false;
                _screenRecordProc.running = true;
                _startRecFlag = false;
            }
        }
    }

    property bool _startRecFlag: false

    property var _screenRecordProc: Process {
        id: screenRecordProc
        property string commandLine: "gpu-screen-recorder -w screen -f 60 -a default_output -o \"$HOME/Videos/screen-recording/sr_$(date +%Y%m%d_%H%M%S).mp4\""
        command: ["bash", "-c", commandLine]
        running: false
        onRunningChanged: {
            root.screenRecordingActive = running;
            if (!running) {
                root.screenRecordingPaused = false;
                root.screenRecordingElapsedSeconds = 0;
                root.screenRecordingElapsedText = "00:00";
            }
        }
    }

    function toggleScreenRecording() {
        if (screenRecordingActive) {
            _screenRecordProc.running = false;
        } else {
            _startRecFlag = true;
            _setupRecDir.running = true;
        }
    }

    property var _pauseProc: Process {
        command: ["killall", "-SIGUSR2", "gpu-screen-recorder"]
        running: false
    }

    function pauseResumeRecording() {
        if (screenRecordingActive) {
            _pauseProc.running = true;
            screenRecordingPaused = !screenRecordingPaused;
        }
    }
}
