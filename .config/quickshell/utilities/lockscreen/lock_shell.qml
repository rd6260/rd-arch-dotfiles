import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./shim"

ShellRoot {
    id: shellRoot

    // ── Config ───────────────────────────────────────────────────────────────

    readonly property string bgImage: Quickshell.shellDir + "/../../assets/lockscreen_bg.png"
    readonly property string fontFile: Quickshell.shellDir + "/../../assets/Itim-Regular.ttf"

    readonly property color cInk: "#4b4b4b"
    readonly property color cSub: "#8b8b8b"
    readonly property color cPink: "#d37785"
    readonly property color cGlass: "#20000000"
    readonly property color cBg: "#f0eee9"

    // ── State ────────────────────────────────────────────────────────────────

    readonly property var sddm: sddmShim.sddm
    readonly property var userModel: sddmShim.userModel
    readonly property var sessionModel: sddmShim.sessionModel
    readonly property bool isWayland: Quickshell.env("XDG_SESSION_TYPE") === "wayland"
    property bool authenticated: false
    property bool sessionLocked: true

    property string systemAmbientText: ""
    property string timeWhisperText: ""

    // ── Shim ─────────────────────────────────────────────────────────────────

    SddmShim {
        id: sddmShim
    }

    Connections {
        target: sddmShim.sddm
        function onLoginSucceeded() {
            shellRoot.authenticated = true;
            if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "")
                Quickshell.execDetached(["hyprctl", "keyword", "misc:allow_session_lock_restore", "1"]);
            Quickshell.execDetached(["loginctl", "unlock-session"]);
            quitTimer.start();
        }
    }

    Timer {
        id: quitTimer
        interval: 300
        onTriggered: {
            shellRoot.sessionLocked = false;
            Qt.quit();
        }
    }

    // ── Some soothing texts ──────────────────────────────────────────────────

    Process {
        command: [Quickshell.env("HOME") + "/.local/bin/lifeos-util", "--system-ambient"]
        // running: true

        stdout: SplitParser {
            // splitMarker: ""
            onRead: text => {
                systemAmbientText = text.trim();
            }
        }
        Component.onCompleted: running = true
    }

    Process {
        command: [Quickshell.env("HOME") + "/.local/bin/lifeos-util", "--time-whisper"]
        // running: true

        stdout: SplitParser {
            // splitMarker: ""
            onRead: text => {
                timeWhisperText = text.trim();
            }
        }
        Component.onCompleted: running = true
    }

    // ── Theme ────────────────────────────────────────────────────────────────

    Component {
        id: themeComponent

        Rectangle {
            id: root
            width: Screen.width
            height: Screen.height
            color: shellRoot.cBg

            readonly property real s: height / 768
            property int sessionIndex: shellRoot.sessionModel.lastIndex >= 0 ? shellRoot.sessionModel.lastIndex : 0
            property int userIndex: shellRoot.userModel.lastIndex >= 0 ? shellRoot.userModel.lastIndex : 0
            property real ui: 0

            FontLoader {
                id: mainFont
                source: "file://" + shellRoot.fontFile
            }

            // Hidden helpers to resolve current user/session names
            ListView {
                id: sessionHelper
                model: shellRoot.sessionModel
                currentIndex: root.sessionIndex
                opacity: 0
                width: 1
                height: 1
                delegate: Item {
                    property string sName: model.name || ""
                }
            }
            ListView {
                id: userHelper
                model: shellRoot.userModel
                currentIndex: root.userIndex
                opacity: 0
                width: 1
                height: 1
                delegate: Item {
                    property string uName: model.realName || model.name || ""
                    property string uLogin: model.name || ""
                }
            }

            Component.onCompleted: {
                fadeAnim.start();
                pwd.forceActiveFocus();
            }
            NumberAnimation {
                id: fadeAnim
                target: root
                property: "ui"
                from: 0
                to: 1
                duration: 1500
                easing.type: Easing.OutCubic
            }

            // Background
            Image {
                anchors.fill: parent
                source: "file://" + shellRoot.bgImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: root.ui
            }

            // Fade-in overlay
            Rectangle {
                anchors.fill: parent
                color: shellRoot.cBg
                opacity: 1.0 - root.ui
                visible: root.ui < 1.0
                z: 100
            }

            // Clock
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 30 * s 
                anchors.leftMargin: 60 * s
                opacity: root.ui

                Column {
                    spacing: -10 * s
                    Text {
                        id: clockText
                        text: Qt.formatTime(new Date(), "HH:mm")
                        color: shellRoot.cInk
                        font.family: mainFont.name
                        font.pixelSize: 84 * s
                        Timer {
                            interval: 1000
                            running: true
                            repeat: true
                            onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
                        }
                    }
                    Text {
                        text: Qt.formatDate(new Date(), "dddd, MMMM d").toLowerCase()
                        color: shellRoot.cSub
                        font.family: mainFont.name
                        font.pixelSize: 18 * s
                        font.letterSpacing: 1 * s
                        bottomPadding: 10 * s
                    }
                    // some soothing time whisper text
                    Text {
                        text: timeWhisperText
                        color: shellRoot.cSub
                        font.family: mainFont.name
                        font.pixelSize: 18 * s
                        font.letterSpacing: 1 * s
                    }
                }
            }

            // Login panel
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.width * 0.20
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.height * 0.20
                width: 250 * s
                height: loginCol.height
                opacity: root.ui

                Column {
                    id: loginCol
                    width: parent.width
                    spacing: 18 * s

                    // Username
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ((userHelper.currentItem?.uName) ?? shellRoot.userModel.lastUser).toUpperCase()
                        color: userMa.containsMouse ? shellRoot.cPink : shellRoot.cInk
                        font.family: mainFont.name
                        font.pixelSize: 18 * s
                        font.letterSpacing: 4 * s
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                        MouseArea {
                            id: userMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.userIndex = (root.userIndex + 1) % shellRoot.userModel.rowCount()
                        }
                    }

                    // Password input
                    Rectangle {
                        width: parent.width
                        height: 42 * s
                        radius: 10 * s
                        color: shellRoot.cGlass
                        border.color: pwd.activeFocus ? shellRoot.cInk : "transparent"
                        border.width: 1 * s
                        Behavior on border.color {
                            ColorAnimation {
                                duration: 300
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.ArrowCursor
                            onClicked: pwd.forceActiveFocus()
                        }

                        TextInput {
                            id: pwd
                            anchors.fill: parent
                            anchors.leftMargin: 15 * s
                            anchors.rightMargin: 15 * s
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            color: shellRoot.cInk
                            font.family: mainFont.name
                            font.pixelSize: 18 * s
                            font.letterSpacing: 8 * s
                            focus: true
                            clip: true
                            cursorVisible: false
                            cursorDelegate: Item {
                                width: 0
                                height: 0
                            }
                            onAccepted: doLogin()

                            // Placeholder
                            Text {
                                anchors.centerIn: parent
                                text: "access key"
                                color: shellRoot.cSub
                                opacity: pwd.text.length === 0 ? 0.6 : 0
                                font.family: mainFont.name
                                font.pixelSize: 14 * s
                                font.letterSpacing: 2 * s
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                    }
                                }
                            }

                            // Blinking cursor
                            Rectangle {
                                id: cursor
                                width: 2 * s
                                height: 18 * s
                                color: shellRoot.cInk
                                anchors.verticalCenter: parent.verticalCenter
                                x: pwd.cursorRectangle.x
                                visible: pwd.focus && pwd.text.length > 0
                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    running: cursor.visible
                                    NumberAnimation {
                                        target: cursor
                                        property: "opacity"
                                        from: 1.0
                                        to: 0.1
                                        duration: 450
                                    }
                                    NumberAnimation {
                                        target: cursor
                                        property: "opacity"
                                        from: 0.1
                                        to: 1.0
                                        duration: 450
                                    }
                                }
                            }
                        }
                    }

                    // Error
                    Text {
                        id: errorMsg
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: ""
                        color: shellRoot.cPink
                        font.family: mainFont.name
                        font.pixelSize: 12 * s
                        font.letterSpacing: 1 * s
                        visible: text !== ""
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: systemAmbientText
                        color: shellRoot.cSub
                        font.family: mainFont.name
                        font.pixelSize: 11 * s
                        font.letterSpacing: s
                    }

                    // Actions
                    // Row {
                    //     anchors.horizontalCenter: parent.horizontalCenter
                    //     spacing: 25 * s
                    //     Repeater {
                    //         model: [
                    //             {
                    //                 l: "SESSION",
                    //                 a: 0
                    //             },
                    //             {
                    //                 l: "REBOOT",
                    //                 a: 1
                    //             },
                    //             {
                    //                 l: "POWER",
                    //                 a: 2
                    //             }
                    //         ]
                    //         delegate: Text {
                    //             text: (modelData.a === 0 && sessionHelper.currentItem) ? sessionHelper.currentItem.sName.toUpperCase() : modelData.l
                    //             color: actMa.containsMouse ? shellRoot.cPink : shellRoot.cSub
                    //             font.family: mainFont.name
                    //             font.pixelSize: 11 * s
                    //             font.letterSpacing: 2 * s
                    //             Behavior on color {
                    //                 ColorAnimation {
                    //                     duration: 200
                    //                 }
                    //             }
                    //             MouseArea {
                    //                 id: actMa
                    //                 anchors.fill: parent
                    //                 hoverEnabled: true
                    //                 cursorShape: Qt.PointingHandCursor
                    //                 onClicked: {
                    //                     if (modelData.a === 0)
                    //                         root.sessionIndex = (root.sessionIndex + 1) % shellRoot.sessionModel.rowCount();
                    //                     else if (modelData.a === 1)
                    //                         shellRoot.sddm.reboot();
                    //                     else if (modelData.a === 2)
                    //                         shellRoot.sddm.powerOff();
                    //                 }
                    //             }
                    //         }
                    //     }
                    // }
                }
            }

            Connections {
                target: shellRoot.sddm
                function onLoginFailed() {
                    errorMsg.text = "try again";
                    pwd.text = "";
                    pwd.forceActiveFocus();
                }
            }

            function doLogin() {
                var u = userHelper.currentItem?.uLogin ?? shellRoot.userModel.lastUser;
                shellRoot.sddm.login(u, pwd.text, root.sessionIndex);
            }
        }
    }

    // ── Display ──────────────────────────────────────────────────────────────

    Loader {
        active: shellRoot.isWayland
        sourceComponent: Component {
            WlSessionLock {
                locked: shellRoot.sessionLocked
                surface: Component {
                    WlSessionLockSurface {
                        color: "black"
                        Loader {
                            anchors.fill: parent
                            sourceComponent: themeComponent
                        }
                    }
                }
            }
        }
    }

    Loader {
        active: !shellRoot.isWayland
        sourceComponent: Component {
            Variants {
                model: Quickshell.screens
                delegate: Window {
                    required property var modelData
                    screen: modelData
                    width: screen.width
                    height: screen.height
                    visible: shellRoot.sessionLocked
                    visibility: Window.FullScreen
                    onClosing: close => {
                        close.accepted = shellRoot.authenticated;
                    }
                    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint | Qt.MaximizeUsingFullscreenGeometryHint
                    color: "black"
                    Loader {
                        anchors.fill: parent
                        sourceComponent: themeComponent
                    }
                }
            }
        }
    }
}
