import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Io
import "."
import "../../theme"
import "../../notifications"

/**
 * The control panel popup content.
 * Anchored to bottom-right inside ControlPanel.qml's PanelWindow.
 */
Item {
    id: panelRoot

    // ── Geometry ────────────────────────────────────────────────────────────
    // Expand to include the fillets (32px above, 32px left) for a fluid morphing curve
    width: 320 + 32
    height: contentCol.implicitHeight + 24 + 32

    // Accept keyboard focus for Escape key
    focus: true
    Keys.onEscapePressed: {
        ControlPanelService.panelOpen = false;
    }

    // ── Pipewire state ───────────────────────────────────────────────────────
    readonly property var activeSink:   Pipewire.defaultAudioSink
    readonly property var activeSource: Pipewire.defaultAudioSource
    readonly property bool speakerMuted: activeSink?.audio?.muted ?? true
    readonly property bool micMuted:     activeSource?.audio?.muted ?? true
    readonly property real speakerVol:   activeSink?.audio?.volume ?? 0.0
    readonly property real micVol:       activeSource?.audio?.volume ?? 0.0

    PwObjectTracker {
        objects: {
            let list = [];
            if (panelRoot.activeSink)   list.push(panelRoot.activeSink);
            if (panelRoot.activeSource) list.push(panelRoot.activeSource);
            return list;
        }
    }

    // ── Bluetooth state ──────────────────────────────────────────────────────
    readonly property bool btEnabled: BluetoothManager.state === BluetoothState.On
                                   || BluetoothManager.state === BluetoothState.TurningOn

    // ── Wi-Fi state ──────────────────────────────────────────────────────────
    property bool wifiEnabled: true
    property bool wifiScanning: false
    property var  wifiNetworks: []
    property string wifiCurrentSsid: ""

    // ── Expanded sub-panel tracking ──────────────────────────────────────────
    // "none" | "wifi" | "speaker" | "mic"
    property string expandedSection: "none"

    // ── Brightness state ───────────────────────────────────────────
    property real brightnessValue: 0.0   // 0.0 – 1.0
    property bool brightnessDragging: false


    // ── Processes ────────────────────────────────────────────────────────────
    Process {
        id: nmcliScan
        command: ["bash", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan yes 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                panelRoot.wifiScanning = false;
                let lines = text.trim().split('\n').filter(l => l.trim() !== "");
                let seen = {};
                let networks = [];
                for (let line of lines) {
                    // Fields: IN-USE:SSID:SIGNAL:SECURITY (colons may appear in SSID, so split carefully)
                    let m = line.match(/^(\*?):(.+):(\d+):(.*)$/);
                    if (!m) continue;
                    let inUse    = m[1] === "*";
                    let ssid     = m[2].trim();
                    let signal   = parseInt(m[3]) || 0;
                    let security = m[4].trim();
                    if (!ssid || ssid === "--") continue;
                    // Deduplicate: keep highest signal per SSID
                    if (seen[ssid] === undefined || signal > seen[ssid]) {
                        seen[ssid] = signal;
                        // Remove previous entry if exists
                        networks = networks.filter(n => n.ssid !== ssid);
                        networks.push({
                            active: inUse,
                            ssid: ssid,
                            signal: signal,
                            secured: security !== "" && security !== "--"
                        });
                    }
                }
                // Sort: active first, then by signal desc
                networks.sort((a, b) => {
                    if (a.active !== b.active) return a.active ? -1 : 1;
                    return b.signal - a.signal;
                });
                panelRoot.wifiNetworks = networks;
                let active = networks.find(n => n.active);
                panelRoot.wifiCurrentSsid = active ? active.ssid : "";
            }
        }
    }

    Process {
        id: nmcliRadio
        property bool targetState: true
        command: ["bash", "-c", targetState ? "nmcli radio wifi on" : "nmcli radio wifi off"]
        running: false
        onRunningChanged: {
            if (!running) {
                panelRoot.wifiEnabled = targetState;
                if (targetState) {
                    panelRoot.wifiScanning = true;
                    nmcliScan.running = true;
                }
            }
        }
    }

    Process {
        id: nmcliConnect
        property string targetSsid: ""
        command: ["bash", "-c", "nmcli device wifi connect \"" + targetSsid + "\" 2>/dev/null"]
        running: false
        onRunningChanged: {
            if (!running) {
                panelRoot.wifiScanning = true;
                nmcliScan.running = true;
            }
        }
    }

    Process {
        id: btRadioCmd
        property bool targetState: true
        command: ["bash", "-c", targetState ? "bluetoothctl power on" : "bluetoothctl power off"]
        running: false
    }

    // Check initial wifi state on startup
    Process {
        id: wifiStateCheck
        command: ["bash", "-c", "nmcli radio wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                panelRoot.wifiEnabled = text.trim() === "enabled";
                if (panelRoot.wifiEnabled) {
                    panelRoot.wifiScanning = true;
                    nmcliScan.running = true;
                }
            }
        }
    }

    // Read current brightness on startup
    Process {
        id: brightnessGet
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}' | tr -d '%'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let pct = parseFloat(text.trim());
                if (!isNaN(pct)) panelRoot.brightnessValue = pct / 100.0;
            }
        }
    }

    // Set brightness (debounced via Timer)
    Process {
        id: brightnessSet
        property real targetVal: 0.0
        command: ["brightnessctl", "s", Math.round(targetVal * 100) + "%"]
        running: false
    }

    Process {
        id: nightLightCmd
        property bool targetState: false
        property int targetTemp: ControlPanelService.nightLightTemp
        command: ["bash", "-c", targetState ? "killall hyprsunset; nohup hyprsunset -t " + targetTemp + " >/dev/null 2>&1 &" : "killall hyprsunset"]
        running: false
    }



    Timer {
        id: nightLightDebounce
        interval: 300
        repeat: false
        onTriggered: {
            if (ControlPanelService.nightLightEnabled) {
                nightLightCmd.running = false;
                nightLightCmd.targetTemp = ControlPanelService.nightLightTemp;
                nightLightCmd.targetState = true;
                nightLightCmd.running = true;
            }
        }
    }

    Timer {
        id: brightnessDebounce
        interval: 80
        repeat: false
        onTriggered: {
            brightnessSet.targetVal = panelRoot.brightnessValue;
            brightnessSet.running = true;
        }
    }

    // ── No Drop shadow for liquid aesthetic ──────────────────────────────────

    // ── Content ──────────────────────────────────────────────────────────────
    // The actual 320px panel container
    Item {
        id: panelBody
        width: 320
        height: contentCol.implicitHeight + 24
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

        // Base shape
        Rectangle {
            anchors.fill: parent
            color: Theme.surface_container_low
            radius: 32 // organic corner radius

            // Square corners touching the bottom and right edges
            Rectangle {
                width: 32; height: 32
                anchors.top: parent.top
                anchors.right: parent.right
                color: Theme.surface_container_low
            }
            Rectangle {
                width: 32; height: 32
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                color: Theme.surface_container_low
            }
            Rectangle {
                width: 32; height: 32
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: Theme.surface_container_low
            }
        }

        // Top-Right Fillet (above the panel, on the right edge)
        Canvas {
            width: 32; height: 32
            anchors.bottom: parent.top
            anchors.right: parent.right
            property color fillColor: Theme.surface_container_low
            onFillColorChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = fillColor;
                ctx.beginPath();
                ctx.moveTo(32, 32);
                ctx.lineTo(32, 0);
                // Fluid bezier curve for surface-tension morphing effect
                ctx.bezierCurveTo(32, 16, 16, 32, 0, 32);
                ctx.lineTo(32, 32);
                ctx.closePath();
                ctx.fill();
            }
        }

        // Bottom-Left Fillet (to the left of the panel, on the bottom edge)
        Canvas {
            width: 32; height: 32
            anchors.bottom: parent.bottom
            anchors.right: parent.left
            property color fillColor: Theme.surface_container_low
            onFillColorChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = fillColor;
                ctx.beginPath();
                ctx.moveTo(32, 32);
                ctx.lineTo(0, 32);
                // Fluid bezier curve for surface-tension morphing effect
                ctx.bezierCurveTo(16, 32, 32, 16, 32, 0);
                ctx.lineTo(32, 32);
                ctx.closePath();
                ctx.fill();
            }
        }

        Column {
            id: contentCol
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: 12

            move: Transition { NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutExpo } }

        // ─── User Identity Section ───────────────────────────────────────────
        Item {
            width: parent.width
            height: 80

            // Avatar
            Item {
                id: avatarFrame
                width: 56
                height: 56
                anchors {
                    left: parent.left
                    leftMargin: 16
                    verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: "file:///home/senku/.face"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: avatarMask
                    }
                }

                // Fallback when image fails / not found
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.primary_container
                    visible: avatarImg.status !== Image.Ready

                    Text {
                        anchors.centerIn: parent
                        text: "S"
                        color: Theme.on_primary_container
                        font { family: "Google Sans Medium"; pixelSize: 22; bold: true }
                    }
                }

                // Online presence ring
                Rectangle {
                    width: 12; height: 12; radius: 6
                    color: "#4caf50"
                    border.width: 2
                    border.color: Theme.surface_container_low
                    anchors { right: parent.right; bottom: parent.bottom }
                }
            }

            // Username + hostname
            Column {
                anchors {
                    left: avatarFrame.right
                    leftMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                spacing: 4

                Text {
                    text: "senku"
                    color: Theme.on_surface
                    font { family: "Google Sans Medium"; pixelSize: 16 }
                }

                Text {
                    text: "@" + ControlPanelService.hostname
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 12 }
                }
            }
        }

        // ─── Active Recording Bar ─────────────────────────────────────────────
        Item {
            width: parent.width
            height: ControlPanelService.screenRecordingActive ? 64 : 0

            Item {
                width: parent.width
                height: parent.height
                clip: activeRecAnim.running
                visible: height > 0
                Behavior on height { NumberAnimation { id: activeRecAnim; duration: 300; easing.type: Easing.OutExpo } }

                Item {
                    width: parent.width
                    height: 64

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 16
                    rightMargin: 16
                    topMargin: 4
                    bottomMargin: 4
                }
                radius: 16
                color: Theme.critical
                opacity: 0.15
            }

            Row {
                anchors {
                    left: parent.left
                    leftMargin: 32
                    verticalCenter: parent.verticalCenter
                }
                spacing: 12

                // Blinking Dot
                Rectangle {
                    width: 10; height: 10
                    radius: 5
                    color: Theme.critical
                    anchors.verticalCenter: parent.verticalCenter
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: ControlPanelService.screenRecordingActive && !ControlPanelService.screenRecordingPaused && panelRoot.scale === 1.0
                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                    opacity: ControlPanelService.screenRecordingPaused ? 0.4 : 1.0
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: ControlPanelService.screenRecordingPaused ? "Paused" : "Recording Screen"
                        color: Theme.on_surface
                        font { family: "Google Sans Medium"; pixelSize: 13 }
                    }
                    Text {
                        text: ControlPanelService.screenRecordingElapsedText
                        color: Theme.critical
                        font { family: "Google Sans Medium"; pixelSize: 11; bold: true }
                    }
                }
            }

            Row {
                anchors {
                    right: parent.right
                    rightMargin: 24
                    verticalCenter: parent.verticalCenter
                }
                spacing: 8

                // Pause/Resume Button
                Rectangle {
                    width: 36; height: 36
                    radius: 18
                    color: pauseHover.hovered ? Theme.surface_container_highest : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: ControlPanelService.screenRecordingPaused ? "󰐊" : "󰏤"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        color: Theme.on_surface
                    }
                    HoverHandler { id: pauseHover }
                    TapHandler {
                        onTapped: ControlPanelService.pauseResumeRecording()
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Stop/Done Button
                Rectangle {
                    width: 36; height: 36
                    radius: 18
                    color: stopHover.hovered ? Theme.surface_container_highest : "transparent"
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰓛"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        color: Theme.critical
                    }
                    HoverHandler { id: stopHover }
                    TapHandler {
                        onTapped: ControlPanelService.toggleScreenRecording()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
                }
            }
        }

        // Section divider
        Rectangle {
            width: parent.width - 32; height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.outline_variant; opacity: 0.5
        }

        // ─── Quick Toggles Grid ──────────────────────────────────────────────
        Item {
            width: parent.width
            height: toggleGrid.implicitHeight + 24

            Grid {
                id: toggleGrid
                anchors {
                    top: parent.top; topMargin: 12
                    left: parent.left; leftMargin: 16
                    right: parent.right; rightMargin: 16
                }
                columns: 3
                rowSpacing: 10
                columnSpacing: 10

                property int cellW: Math.floor((width - columnSpacing * (columns - 1)) / columns)

                // ── Keep Awake ──
                ToggleButton {
                    icon: ControlPanelService.keepAwakeEnabled ? "󰈂" : "󰈀"
                    label: "Awake"
                    active: ControlPanelService.keepAwakeEnabled
                    cellWidth: toggleGrid.cellW
                    onToggled: ControlPanelService.keepAwakeEnabled = !ControlPanelService.keepAwakeEnabled
                }

                // ── Bluetooth ──
                ToggleButton {
                    icon: panelRoot.btEnabled ? "󰂯" : "󰂲"
                    label: "Bluetooth"
                    active: panelRoot.btEnabled
                    cellWidth: toggleGrid.cellW
                    onToggled: {
                        btRadioCmd.targetState = !panelRoot.btEnabled;
                        btRadioCmd.running = true;
                    }
                }

                // ── Wi-Fi ──
                ToggleButton {
                    icon: panelRoot.wifiEnabled ? "󰤨" : "󰤭"
                    label: panelRoot.wifiCurrentSsid !== "" ? panelRoot.wifiCurrentSsid : "Wi-Fi"
                    active: panelRoot.wifiEnabled
                    loading: panelRoot.wifiScanning
                    hasDropdown: panelRoot.wifiEnabled
                    dropdownOpen: panelRoot.expandedSection === "wifi"
                    cellWidth: toggleGrid.cellW
                    onToggled: {
                        if (!panelRoot.wifiEnabled) {
                            // Turn on wifi
                            nmcliRadio.targetState = true;
                            nmcliRadio.running = true;
                        } else if (panelRoot.expandedSection === "wifi") {
                            panelRoot.expandedSection = "none";
                        } else {
                            panelRoot.expandedSection = "wifi";
                        }
                    }
                    onLongToggled: {
                        panelRoot.expandedSection = "none";
                        nmcliRadio.targetState = !panelRoot.wifiEnabled;
                        nmcliRadio.running = true;
                    }
                }

                // ── Speaker ──
                ToggleButton {
                    icon: panelRoot.speakerMuted ? "󰖁"
                        : panelRoot.speakerVol >= 0.6 ? "󰕾"
                        : panelRoot.speakerVol >= 0.3 ? "󰖀" : "󰕿"
                    label: panelRoot.speakerMuted ? "Muted" : Math.round(panelRoot.speakerVol * 100) + "%"
                    active: !panelRoot.speakerMuted
                    hasDropdown: true
                    dropdownOpen: panelRoot.expandedSection === "speaker"
                    cellWidth: toggleGrid.cellW
                    onToggled: {
                        panelRoot.expandedSection = panelRoot.expandedSection === "speaker" ? "none" : "speaker";
                    }
                    onLongToggled: {
                        if (panelRoot.activeSink?.audio)
                            panelRoot.activeSink.audio.muted = !panelRoot.speakerMuted;
                    }
                }

                // ── Mic ──
                ToggleButton {
                    icon: panelRoot.micMuted ? "󰍭" : "󰍬"
                    label: panelRoot.micMuted ? "Muted" : Math.round(panelRoot.micVol * 100) + "%"
                    active: !panelRoot.micMuted
                    hasDropdown: true
                    dropdownOpen: panelRoot.expandedSection === "mic"
                    cellWidth: toggleGrid.cellW
                    onToggled: {
                        panelRoot.expandedSection = panelRoot.expandedSection === "mic" ? "none" : "mic";
                    }
                    onLongToggled: {
                        if (panelRoot.activeSource?.audio)
                            panelRoot.activeSource.audio.muted = !panelRoot.micMuted;
                    }
                }

                // ── DND ──
                ToggleButton {
                    icon: NotifHistoryService.dndEnabled ? "󰂛" : "󰂚"
                    label: "DND"
                    active: NotifHistoryService.dndEnabled
                    cellWidth: toggleGrid.cellW
                    onToggled: NotifHistoryService.dndEnabled = !NotifHistoryService.dndEnabled
                }

                // ── Night Light ──
                ToggleButton {
                    icon: "󰖔"
                    label: "Night Light"
                    active: ControlPanelService.nightLightEnabled
                    cellWidth: toggleGrid.cellW
                    onToggled: {
                        let newState = !ControlPanelService.nightLightEnabled;
                        ControlPanelService.nightLightEnabled = newState;
                        nightLightCmd.running = false;
                        nightLightCmd.targetState = newState;
                        nightLightCmd.running = true;
                    }
                }

                // ── Screen Record ──
                ToggleButton {
                    icon: ControlPanelService.screenRecordingActive ? "󰻃" : "󰻂"
                    label: ControlPanelService.screenRecordingActive ? "Recording" : "Record"
                    active: ControlPanelService.screenRecordingActive
                    cellWidth: toggleGrid.cellW
                    onToggled: ControlPanelService.toggleScreenRecording()
                }

                // ── Tailscale ──
                ToggleButton {
                    icon: ControlPanelService.tailscaleEnabled ? "󰲝" : "󰲜"
                    label: "Tailscale"
                    active: ControlPanelService.tailscaleEnabled
                    cellWidth: toggleGrid.cellW
                    onToggled: ControlPanelService.toggleTailscale()
                }
            }
        }

        // ─── Sliders ──────────────────────────────────────────────────
        Column {
            width: parent.width
            padding: 0
            topPadding: 4
            bottomPadding: 8
            spacing: 2
            
            move: Transition { NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutExpo } }

            // ── Volume slider ──
            SliderRow {
                icon: panelRoot.speakerMuted ? "󰖁"
                    : panelRoot.speakerVol >= 0.6 ? "󰕾"
                    : panelRoot.speakerVol >= 0.3 ? "󰖀" : "󰕿"
                value: panelRoot.speakerVol
                active: !panelRoot.speakerMuted
                width: parent.width
                onSliderMoved: value => {
                    if (panelRoot.activeSink?.audio) {
                        panelRoot.activeSink.audio.volume = value;
                        if (panelRoot.speakerMuted)
                            panelRoot.activeSink.audio.muted = false;
                    }
                }
                onIconClicked: {
                    if (panelRoot.activeSink?.audio)
                        panelRoot.activeSink.audio.muted = !panelRoot.speakerMuted;
                }
            }

            // ── Brightness slider ──
            SliderRow {
                icon: panelRoot.brightnessValue >= 0.7 ? "󰖙"
                    : panelRoot.brightnessValue >= 0.4 ? "󰖜"
                    : panelRoot.brightnessValue >= 0.1 ? "󰖛" : "󰖚"
                value: panelRoot.brightnessValue
                active: panelRoot.brightnessValue > 0.0
                accentColor: "#f9a825"
                width: parent.width
                onSliderMoved: value => {
                    if (!panelRoot.brightnessDragging) return;
                    panelRoot.brightnessValue = value;
                    brightnessDebounce.restart();
                }
                onDragStarted:  panelRoot.brightnessDragging = true
                onDragFinished: {
                    panelRoot.brightnessDragging = false;
                    brightnessDebounce.restart();
                }
            }

            // ── Night Light slider ──
            Item {
                width: parent.width
                height: ControlPanelService.nightLightEnabled ? 40 : 0

                Item {
                    width: parent.width
                    height: parent.height
                    clip: nlAnim.running
                    visible: height > 0
                    Behavior on height { NumberAnimation { id: nlAnim; duration: 300; easing.type: Easing.OutExpo } }

                    Item {
                        width: parent.width
                        height: 40

                SliderRow {
                    icon: "󰖔"
                    // Maps 6500K (normal) to 0.0, and 2000K (warmest) to 1.0
                    value: (6500 - ControlPanelService.nightLightTemp) / 4500.0
                    active: true
                    accentColor: "#ff9800"
                    width: parent.width
                    onSliderMoved: val => {
                        let temp = Math.round(6500 - (val * 4500));
                        ControlPanelService.nightLightTemp = Math.max(2000, Math.min(6500, temp));
                        nightLightDebounce.restart();
                    }
                    onDragFinished: {
                        nightLightDebounce.restart();
                    }
                }
                    }
                }
            }
        }

        // ─── Wi-Fi Network List ──────────────────────────────────────────────
        Item {
            id: wifiExpandItem
            width: parent.width
            height: panelRoot.expandedSection === "wifi" ? wifiInner.implicitHeight + 8 : 0

            Item {
                width: parent.width
                height: parent.height
                clip: wifiAnim.running
                visible: height > 0
                Behavior on height { NumberAnimation { id: wifiAnim; duration: 300; easing.type: Easing.OutExpo } }

            Column {
                id: wifiInner
                width: parent.width
                topPadding: 4
                bottomPadding: 4

                // Sub-header row
                Item {
                    width: parent.width
                    height: 32

                    Text {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        text: "Networks"
                        color: Theme.on_surface_variant
                        font { family: "Google Sans Medium"; pixelSize: 11 }
                    }

                    // Refresh icon (animates while scanning)
                    Item {
                        id: refreshBtn
                        width: 28; height: 28
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }

                        Text {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: "󰑐"
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                            color: refreshHover.containsMouse ? Theme.primary : Theme.on_surface_variant
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RotationAnimator {
                            target: refreshIcon
                            running: panelRoot.wifiScanning
                            from: 0; to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }

                        HoverHandler { id: refreshHover }
                        TapHandler {
                            cursorShape: Qt.PointingHandCursor
                            onTapped: { panelRoot.wifiScanning = true; nmcliScan.running = true; }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 32; height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.outline_variant; opacity: 0.4
                }

                // Scanning / empty placeholder
                Item {
                    width: parent.width
                    height: panelRoot.wifiNetworks.length === 0 ? 40 : 0
                    visible: height > 0
                    Text {
                        anchors.centerIn: parent
                        text: panelRoot.wifiScanning ? "Scanning…" : "No networks found"
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 12 }
                        opacity: 0.6
                    }
                }

                // Network rows — Repeater so implicitHeight tracks correctly
                Repeater {
                    model: panelRoot.wifiNetworks

                    delegate: WifiNetworkDelegate {
                        required property var modelData
                        network: modelData
                        width: wifiInner.width
                        onConnectRequested: ssid => {
                            nmcliConnect.targetSsid = ssid;
                            nmcliConnect.running = true;
                        }
                    }
                }
            }
            }
        }

        // ─── Speaker Device List ─────────────────────────────────────────────
        Item {
            width: parent.width
            // implicitHeight of speakerColumn (a Column) is reliably the sum of its children
            height: panelRoot.expandedSection === "speaker" ? speakerColumn.implicitHeight + 8 : 0

            Item {
                width: parent.width
                height: parent.height
                clip: speakerAnim.running
                visible: height > 0
                Behavior on height { NumberAnimation { id: speakerAnim; duration: 300; easing.type: Easing.OutExpo } }

            Column {
                id: speakerColumn
                width: parent.width
                topPadding: 4

                Item {
                    width: parent.width; height: 32
                    Text {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        text: "Output Device"
                        color: Theme.on_surface_variant
                        font { family: "Google Sans Medium"; pixelSize: 11 }
                    }
                }

                Rectangle {
                    width: parent.width - 32; height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.outline_variant; opacity: 0.4
                }

                // Repeater in Column: each item's actual height drives implicitHeight correctly.
                // Items with height:0 are excluded from layout (unlike ListView).
                Column {
                    id: speakerDevices
                    width: parent.width

                    Repeater {
                        model: Pipewire.nodes
                        delegate: AudioDeviceDelegate {
                            required property var modelData
                            visible: modelData.isSink && !modelData.isStream && modelData.audio != null
                            height: visible ? 44 : 0
                            device: modelData
                            activeDevice: panelRoot.activeSink
                            isSink: true
                            width: speakerDevices.width
                        }
                    }
                }
            }
            }
        }

        // ─── Mic Device List ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: panelRoot.expandedSection === "mic" ? micColumn.implicitHeight + 8 : 0

            Item {
                width: parent.width
                height: parent.height
                clip: micAnim.running
                visible: height > 0
                Behavior on height { NumberAnimation { id: micAnim; duration: 300; easing.type: Easing.OutExpo } }

            Column {
                id: micColumn
                width: parent.width
                topPadding: 4

                Item {
                    width: parent.width; height: 32
                    Text {
                        anchors { left: parent.left; leftMargin: 20; verticalCenter: parent.verticalCenter }
                        text: "Input Device"
                        color: Theme.on_surface_variant
                        font { family: "Google Sans Medium"; pixelSize: 11 }
                    }
                }

                Rectangle {
                    width: parent.width - 32; height: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.outline_variant; opacity: 0.4
                }

                // Repeater in Column for reliable implicitHeight tracking
                Column {
                    id: micDevices
                    width: parent.width

                    Repeater {
                        model: Pipewire.nodes
                        delegate: AudioDeviceDelegate {
                            required property var modelData
                            visible: !modelData.isSink && !modelData.isStream && modelData.audio != null
                            height: visible ? 44 : 0
                            device: modelData
                            activeDevice: panelRoot.activeSource
                            isSink: false
                            width: micDevices.width
                        }
                    }
                }
            }
            }
        }

        // Bottom padding
        Item { width: 1; height: 12 }
    }
    }

    // ── Inline ToggleButton component ──────────────────────────────────────
    component ToggleButton: Item {
    id: btn

    property string icon: ""
    property string label: ""
    property bool   active: false
    property bool   loading: false
    property bool   hasDropdown: false
    property bool   dropdownOpen: false
    property int    cellWidth: 88

    signal toggled()
    signal longToggled()

    width: cellWidth
    height: 72

    Rectangle {
        id: btnBg
        anchors.fill: parent
        radius: 14
        color: btn.active ? Theme.primary_container : Theme.surface_container_high

        Behavior on color { ColorAnimation { duration: 160 } }

        // Press / hover ripple
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: hoverHandler.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                // Main icon
                Text {
                    id: mainIcon
                    text: btn.icon
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                    color: btn.active ? Theme.on_primary_container : Theme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                // Dropdown chevron
                Text {
                    visible: btn.hasDropdown
                    text: btn.dropdownOpen ? "󰅀" : "󰅂"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                    color: btn.active ? Theme.on_primary_container : Theme.on_surface_variant
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            Text {
                text: btn.label
                color: btn.active ? Theme.on_primary_container : Theme.on_surface_variant
                font { family: "Google Sans Medium"; pixelSize: 10 }
                elide: Text.ElideRight
                width: Math.min(implicitWidth, btn.width - 12)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        HoverHandler { id: hoverHandler }

        TapHandler {
            id: tapHandler
            cursorShape: Qt.PointingHandCursor
            longPressThreshold: 0.6
            onTapped: btn.toggled()
            onLongPressed: btn.longToggled()
        }
    }
}

    // ── Inline SliderRow component ───────────────────────────────────────────
    component SliderRow: Item {
        id: sliderRoot

        property string icon: ""
        property real   value: 0.0 // 0.0 to 1.0
        property bool   active: true
        property string accentColor: Theme.primary

        signal sliderMoved(real value)
        signal iconClicked()
        signal dragStarted()
        signal dragFinished()

        height: 40

        Row {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 12

            // Icon Button
            Item {
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: iconHover.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: sliderRoot.icon
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                    color: sliderRoot.active ? sliderRoot.accentColor : Theme.on_surface_variant
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                HoverHandler { id: iconHover }
                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: sliderRoot.iconClicked()
                }
            }

            // Slider Track
            Item {
                id: trackArea
                width: parent.width - 44
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                // Background track
                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: Theme.surface_container_high
                    
                    // Hover effect
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: mouseArea.containsMouse ? Qt.alpha(Theme.on_surface, 0.04) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                }

                // Fill track
                Rectangle {
                    width: Math.max(18, trackArea.width * sliderRoot.value)
                    height: 18
                    radius: 9
                    color: sliderRoot.active ? sliderRoot.accentColor : Theme.outline_variant
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    function updateValue(mx) {
                        let val = Math.max(0.0, Math.min(1.0, mx / width));
                        sliderRoot.sliderMoved(val);
                    }
                    
                    onPressed: mouse => {
                        sliderRoot.dragStarted();
                        updateValue(mouse.x);
                    }
                    onPositionChanged: mouse => {
                        if (pressed) updateValue(mouse.x);
                    }
                    onReleased: mouse => {
                        sliderRoot.dragFinished();
                    }
                }
            }
        }
    }
}
