import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: root

    property string binaryPath: "/home/senku/.config/quickshell/utilities/sync-lyrics/target/release/synced-lyrics"
    property int slideOffset: 40
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
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
            }

            function setLine(text) {
                // Stop all animations first
                slideOutA.stop(); slideInA.stop();
                slideOutB.stop(); slideInB.stop();
                
                if (showingA) {
                    textB.text = text;
                    textB.y = root.slideOffset;  // instant: below center
                    textB.opacity = 0;           // instant: invisible
                    slideOutA.start();           // A slides up and out
                    slideInB.start();            // B slides up into center
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
                height: 0 // Center y=0 perfectly on screen center
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
                    // Center vertically relative to y=0
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

    Process {
        id: lyricsProcess
        command: [binaryPath]
        running: true
        
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
            if (!running) {
                restartTimer.start();
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: lyricsProcess.running = true
    }
}
