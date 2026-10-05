import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../../control-panel"

/**
 * Synced-lyrics overlay — meant to be embedded directly in the main ShellRoot.
 *
 * Reads JSON events from the synced-lyrics binary and renders the current lyric
 * line as a centred, animated overlay on every screen. The overlay is
 * completely transparent to input (click-through).
 *
 * Visibility is controlled by ControlPanelService.lyricsEnabled so it can be
 * toggled from the control panel without restarting the shell.
 */
QtObject {
    id: root

    readonly property string binaryPath: "/home/senku/.config/quickshell/utilities/sync-lyrics/target/release/synced-lyrics"
    readonly property int slideOffset: 40

    property string currentLyric: ""
    property bool isPlaying: false
    property bool hasLyric: false

    function handleEvent(event) {
        switch (event.type) {
            case "lyric":
                if (event.text && event.text.length > 0) {
                    hasLyric = true;
                    currentLyric = event.text;
                } else {
                    hasLyric = false;
                }
                break;
            case "clear":
                hasLyric = false;
                break;
            case "state":
                isPlaying = event.playing;
                break;
        }
    }

    // ── Per-screen overlay windows ───────────────────────────────────────────
    property var _screens: Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            property var modelData
            screen: modelData

            // Only show when lyrics are enabled
            visible: ControlPanelService.lyricsEnabled

            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true; bottom: true; left: true; right: true
            }
            color: "transparent"
            mask: Region {}  // empty input region = click-through

            property bool showingA: false

            Connections {
                target: root
                function onCurrentLyricChanged() {
                    if (root.hasLyric) {
                        window.setLine(root.currentLyric);
                    }
                }
                function onHasLyricChanged() {
                    if (!root.hasLyric) {
                        // fade both texts out instantly when there's no lyric
                        textA.opacity = 0;
                        textB.opacity = 0;
                    }
                }
            }

            function setLine(text) {
                slideOutA.stop(); slideInA.stop();
                slideOutB.stop(); slideInB.stop();

                if (showingA) {
                    textB.text = text;
                    textB.y = root.slideOffset;
                    textB.opacity = 0;
                    slideOutA.start();
                    slideInB.start();
                    showingA = false;
                } else {
                    textA.text = text;
                    textA.y = root.slideOffset;
                    textA.opacity = 0;
                    slideOutB.start();
                    slideInA.start();
                    showingA = true;
                }
            }

            Item {
                id: container
                anchors.centerIn: parent
                width: parent.width
                height: 0  // y=0 is perfectly centred on screen
                visible: root.hasLyric
                opacity: root.isPlaying ? 1.0 : 0.4

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                Text {
                    id: textA
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.75
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "sans-serif"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                    color: "#ffffff"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                    wrapMode: Text.WordWrap
                    opacity: 0
                    transform: Translate { y: -textA.height / 2 }
                }

                Text {
                    id: textB
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.75
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "sans-serif"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.5
                    color: "#ffffff"
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.5)
                    wrapMode: Text.WordWrap
                    opacity: 0
                    transform: Translate { y: -textB.height / 2 }
                }
            }

            ParallelAnimation {
                id: slideOutA
                NumberAnimation { target: textA; property: "y"; to: -root.slideOffset; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { target: textA; property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                id: slideInA
                NumberAnimation { target: textA; property: "y"; to: 0; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { target: textA; property: "opacity"; to: 1; duration: 120; easing.type: Easing.OutCubic }
            }

            ParallelAnimation {
                id: slideOutB
                NumberAnimation { target: textB; property: "y"; to: -root.slideOffset; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { target: textB; property: "opacity"; to: 0; duration: 120; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                id: slideInB
                NumberAnimation { target: textB; property: "y"; to: 0; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { target: textB; property: "opacity"; to: 1; duration: 120; easing.type: Easing.OutCubic }
            }
        }
    }

    // ── Backend process ──────────────────────────────────────────────────────
    property var _process: Process {
        id: lyricsProcess
        command: [root.binaryPath]
        running: ControlPanelService.lyricsEnabled

        stdout: SplitParser {
            onRead: data => {
                try {
                    var event = JSON.parse(data);
                    root.handleEvent(event);
                } catch (e) {
                    // Ignore malformed lines
                }
            }
        }

        onRunningChanged: {
            if (!running && ControlPanelService.lyricsEnabled) {
                restartTimer.start();
            }
        }
    }

    property var _restartTimer: Timer {
        id: restartTimer
        interval: 3000
        onTriggered: {
            if (ControlPanelService.lyricsEnabled)
                lyricsProcess.running = true;
        }
    }
}
