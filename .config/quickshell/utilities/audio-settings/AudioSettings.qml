import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../control-panel"
import "../../theme"
import "audio.js" as A

/**
 * Sound settings window, opened from the arrow next to the volume slider in
 * the control panel. Tabs: Output (devices + combined output), Input
 * (devices + apps recording), Apps (per-app playback volume).
 */
LazyLoader {
    id: loader
    active: ControlPanelService.audioSettingsOpen

    FloatingWindow {
        id: win
        title: "Sound Settings"
        implicitWidth: 560
        implicitHeight: 720
        // min == max makes the window non-resizable, which Hyprland treats as
        // "float this window", so no window rule is needed.
        minimumSize: Qt.size(implicitWidth, implicitHeight)
        maximumSize: Qt.size(implicitWidth, implicitHeight)
        color: Theme.surface
        visible: true

        // Closed from the compositor (or Escape) → drop the loader
        onVisibleChanged: if (!visible) ControlPanelService.audioSettingsOpen = false

        // Bind every device and stream so `audio` and `properties` are live
        PwObjectTracker {
            objects: Pipewire.nodes.values.filter(n => n.audio != null || n.isStream || n.isSink)
        }

        readonly property var defaultSink: Pipewire.defaultAudioSink
        readonly property var defaultSource: Pipewire.defaultAudioSource
        readonly property var outputs:   Pipewire.nodes.values.filter(n => A.isOutputDevice(n))
        readonly property var inputs:    Pipewire.nodes.values.filter(n => A.isInputDevice(n))
        readonly property var playback:  Pipewire.nodes.values.filter(n => A.isPlayback(n))
        readonly property var recording: Pipewire.nodes.values.filter(n => A.isRecording(n))

        // 0 Output · 1 Input · 2 Apps
        property int tab: 0

        // ── Combined output membership ──────────────────────────────────────
        // While the combined output is on, the output cards turn into a
        // checklist of the devices it plays to.
        readonly property bool combineActive: ControlPanelService.btCombineActive
        // Names picked in the UI but not yet saved (saves are debounced)
        property var pendingMembers: null
        readonly property var memberNames: {
            if (pendingMembers !== null) return pendingMembers;
            const saved = ControlPanelService.btCombineMembers;
            if (saved.length > 0) return saved;
            // Nothing saved yet: every Bluetooth output
            return outputs.filter(n => A.kind(n) === "bluetooth").map(n => n.name);
        }
        readonly property var memberKeys: memberNames.map(A.memberKey)
        readonly property var members: outputs.filter(n => memberKeys.includes(A.memberKey(n.name)))

        function isMember(n) { return memberKeys.includes(A.memberKey(n.name)); }

        function toggleMember(n) {
            const key = A.memberKey(n.name);
            // Saved members that aren't connected right now are kept
            let next = memberNames.filter(x => A.memberKey(x) !== key);
            if (!memberKeys.includes(key)) next.push(n.name);
            pendingMembers = next;
            applyMembers.restart();
        }

        Timer {
            id: applyMembers
            interval: 700
            onTriggered: {
                ControlPanelService.setBtCombineMembers(win.pendingMembers);
                win.pendingMembers = null;
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: ControlPanelService.audioSettingsOpen = false

            // ── Header ──────────────────────────────────────────────────────
            Column {
                id: header
                x: 24; y: 24
                width: parent.width - 48 - closeBtn.width
                spacing: 4

                Text {
                    text: "Sound"
                    color: Theme.on_surface
                    font { family: "Google Sans Medium"; pixelSize: 26 }
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 13 }
                    text: {
                        const s = win.defaultSink;
                        if (!s) return "No output device";
                        return "Playing on " + (s.name === "combine_bt" ? "Combined output" : A.label(s));
                    }
                }
            }

            // ── Close ───────────────────────────────────────────────────────
            Rectangle {
                id: closeBtn
                anchors { top: parent.top; topMargin: 20; right: parent.right; rightMargin: 20 }
                width: 36; height: 36; radius: 18
                color: closeHover.hovered ? Theme.surface_container_high : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                    color: closeHover.hovered ? Theme.on_surface : Theme.on_surface_variant
                }

                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: ControlPanelService.audioSettingsOpen = false }
            }

            // ── Tabs ────────────────────────────────────────────────────────
            Rectangle {
                id: tabBar
                x: 24
                anchors { top: header.bottom; topMargin: 20 }
                width: parent.width - 48
                height: 44
                radius: 22
                color: Theme.surface_container

                readonly property var labels: ["Output", "Input", "Apps"]
                readonly property real segW: (width - 8) / labels.length

                // Selected segment
                Rectangle {
                    x: 4 + win.tab * tabBar.segW
                    y: 4
                    width: tabBar.segW
                    height: parent.height - 8
                    radius: height / 2
                    color: Theme.secondary_container
                    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }

                Row {
                    x: 4; y: 4
                    Repeater {
                        model: tabBar.labels
                        delegate: Item {
                            id: seg
                            required property string modelData
                            required property int index
                            readonly property bool selected: win.tab === index
                            readonly property int count: index === 2 ? win.playback.length : 0

                            width: tabBar.segW
                            height: tabBar.height - 8

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: seg.modelData
                                    color: seg.selected ? Theme.on_secondary_container : Theme.on_surface_variant
                                    font { family: "Google Sans Medium"; pixelSize: 13 }
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                }
                                // Number of apps playing
                                Rectangle {
                                    visible: seg.count > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(18, countText.implicitWidth + 10)
                                    height: 18; radius: 9
                                    color: seg.selected ? Theme.primary : Theme.surface_container_highest
                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: seg.count
                                        color: seg.selected ? Theme.on_primary : Theme.on_surface_variant
                                        font { family: "Google Sans Medium"; pixelSize: 10 }
                                    }
                                }
                            }

                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.tab = seg.index }
                        }
                    }
                }
            }

            // ── Pages ───────────────────────────────────────────────────────
            Flickable {
                id: flick
                anchors {
                    top: tabBar.bottom; topMargin: 8
                    left: parent.left; right: parent.right; bottom: parent.bottom
                }
                contentWidth: width
                contentHeight: page.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Back to the top when switching tabs
                Connections {
                    target: win
                    function onTabChanged() { flick.contentY = 0; }
                }

                Column {
                    id: page
                    x: 24
                    width: flick.width - 48
                    topPadding: 8
                    bottomPadding: 24
                    spacing: 10

                    // ── Output ──
                    SectionLabel { visible: win.tab === 0; text: win.combineActive ? "Play to" : "Output device" }
                    Repeater {
                        model: win.tab === 0 ? win.outputs : []
                        delegate: DeviceCard {
                            required property var modelData
                            width: page.width
                            node: modelData
                            isDefault: win.defaultSink !== null && modelData.name === win.defaultSink.name
                            onSelected: Pipewire.preferredDefaultAudioSink = modelData
                            // Combined output on: the card becomes a checkbox row
                            checkable: win.combineActive
                            checked: win.isMember(modelData)
                            // At least one device has to stay selected
                            checkLocked: checked && win.members.length <= 1
                            onCheckToggled: win.toggleMember(modelData)
                        }
                    }
                    EmptyState {
                        visible: win.tab === 0 && win.outputs.length === 0
                        icon: "󰓄"; text: "No output devices"
                    }
                    SectionLabel { visible: win.tab === 0; text: "Multiple devices" }
                    CombinedOutputCard {
                        visible: win.tab === 0
                        width: page.width
                        members: win.members
                    }

                    // ── Input ──
                    SectionLabel { visible: win.tab === 1; text: "Input device" }
                    Repeater {
                        model: win.tab === 1 ? win.inputs : []
                        delegate: DeviceCard {
                            required property var modelData
                            width: page.width
                            node: modelData
                            input: true
                            isDefault: win.defaultSource !== null && modelData.name === win.defaultSource.name
                            onSelected: Pipewire.preferredDefaultAudioSource = modelData
                        }
                    }
                    EmptyState {
                        visible: win.tab === 1 && win.inputs.length === 0
                        icon: "󰍭"; text: "No input devices"
                    }
                    SectionLabel {
                        visible: win.tab === 1 && win.recording.length > 0
                        text: "Apps using input"
                    }
                    Repeater {
                        model: win.tab === 1 ? win.recording : []
                        delegate: AppRow {
                            required property var modelData
                            width: page.width
                            node: modelData
                            input: true
                        }
                    }

                    // ── Apps ──
                    SectionLabel { visible: win.tab === 2 && win.playback.length > 0; text: "Playing audio" }
                    Repeater {
                        model: win.tab === 2 ? win.playback : []
                        delegate: AppRow {
                            required property var modelData
                            width: page.width
                            node: modelData
                        }
                    }
                    EmptyState {
                        visible: win.tab === 2 && win.playback.length === 0
                        icon: "󰝛"; text: "Nothing is playing"
                        hint: "Apps show up here while they play audio"
                    }
                }
            }

            // Scroll indicator
            Rectangle {
                visible: flick.contentHeight > flick.height
                anchors.right: parent.right
                anchors.rightMargin: 6
                y: flick.y + flick.visibleArea.yPosition * flick.height
                width: 4
                height: flick.visibleArea.heightRatio * flick.height
                radius: 2
                color: Theme.outline_variant
                opacity: flick.moving ? 0.9 : 0.4
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }
}
