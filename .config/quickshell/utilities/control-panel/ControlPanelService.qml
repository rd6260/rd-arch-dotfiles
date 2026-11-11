pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

/**
 * Singleton holding all shared state for the control panel.
 * Hostname is fetched once on startup.
 */
QtObject {
    id: root

    // --- Panel visibility ---
    property bool panelOpen: false
    // Name of the screen the panel is open on
    property string panelScreen: ""

    // --- Audio settings window ---
    property bool audioSettingsOpen: false

    // --- Combined audio output ---
    // One virtual sink ("combine_bt") that plays to several outputs at once.
    // It runs in its own PipeWire instance managed by scripts/bt-combine.sh.
    // State is read straight from PipeWire: on == the combine_bt node exists.
    readonly property string _combineScript: Quickshell.shellDir + "/scripts/bt-combine.sh"
    readonly property var btCombineNode: Pipewire.nodes.values.find(n => n.name === "combine_bt") ?? null
    readonly property bool btCombineActive: btCombineNode !== null
    property bool btCombineBusy: false
    property bool _btCombineMakeDefault: false

    // Saved member sink names. Empty = default (every Bluetooth output).
    property var btCombineMembers: []
    property bool btCombineMembersLoaded: false

    property var _btCombineProc: Process {
        property string action: "on"
        command: [root._combineScript, action]
        onExited: (code, status) => { if (code !== 0) root.btCombineBusy = false; }
    }

    property var _btCombineMembersGet: Process {
        command: [root._combineScript, "members"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.btCombineMembers = text.split("\n").map(l => l.trim()).filter(l => l !== "");
                root.btCombineMembersLoaded = true;
            }
        }
    }

    property var _btCombineMembersSet: Process {}

    // Fallback in case the node never shows up / goes away
    property var _btCombineTimeout: Timer {
        interval: 5000
        onTriggered: root.btCombineBusy = false
    }

    onBtCombineNodeChanged: {
        btCombineBusy = false;
        _btCombineTimeout.stop();
        // Route audio to the combined sink as soon as it appears
        if (btCombineNode && _btCombineMakeDefault) {
            _btCombineMakeDefault = false;
            Pipewire.preferredDefaultAudioSink = btCombineNode;
        }
    }

    function setBtCombine(on) {
        if (btCombineBusy || on === btCombineActive) return;
        btCombineBusy = true;
        _btCombineMakeDefault = on;
        _btCombineProc.action = on ? "on" : "off";
        _btCombineProc.running = true;
        _btCombineTimeout.restart();
    }

    // Save the member list; a running combined sink is restarted with it.
    function setBtCombineMembers(names) {
        btCombineMembers = names;
        // Restarting drops the node for a moment; keep it as the default output
        if (btCombineActive && Pipewire.defaultAudioSink === btCombineNode)
            _btCombineMakeDefault = true;
        _btCombineMembersSet.running = false;
        _btCombineMembersSet.command = [_combineScript, "set-members"].concat(names);
        _btCombineMembersSet.running = true;
    }

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

    // --- Phone Presence (auto-lock) ---
    // Enabled == the phone-present binary is running. It locks the session
    // whenever the phone is not nearby.
    // On by default: starts with the shell.
    property bool phonePresenceEnabled: true
    // Latest report from the binary: "" (not known yet) | "present" | "absent"
    property string phoneState: ""
    property string phoneName: ""

    property var _phoneProc: Process {
        running: root.phonePresenceEnabled
        // Settings come from ~/.config/quickshell/config.json ("phone_present")
        command: ["/home/senku/.config/quickshell/native/target/release/phone-present"]
        stdout: SplitParser {
            onRead: line => {
                // "present <label>" / "absent <label>"
                let i = line.indexOf(" ");
                root.phoneState = i < 0 ? line : line.slice(0, i);
                root.phoneName = i < 0 ? "" : line.slice(i + 1);
            }
        }
        // If the binary dies (e.g. Bluetooth off), reflect that in the button.
        onRunningChanged: if (!running) {
            root.phonePresenceEnabled = false;
            root.phoneState = "";
        }
    }

    function togglePhonePresence() {
        phonePresenceEnabled = !phonePresenceEnabled;
    }

    // --- Keep Awake (UI only, backend to be implemented) ---
    property bool keepAwakeEnabled: false

    // --- Synced Lyrics overlay ---
    property bool lyricsEnabled: false

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
