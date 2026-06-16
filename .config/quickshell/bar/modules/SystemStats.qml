import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import qs.theme
// import Quickshell.Bluetooth
import qs.notifications
import Quickshell.Hyprland
import Quickshell.Io
import "../../utilities/control-panel"

/**
 * A unified system status indicator for Audio (Pipewire) and Power (UPower).
 */
Rectangle {
    id: root

    // --- Window Reference ---
    property var panelWindow: null

    // --- Layout Configuration ---
    implicitWidth: contentLayout.width + 30
    implicitHeight: Layout.islandHeight
    color: Theme.surface_container
    radius: height / 2

    // --- Audio State Management ---
    readonly property var activeSink: Pipewire.defaultAudioSink
    readonly property bool isMuted: activeSink?.audio?.muted ?? true
    readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0

    /** Ensures Pipewire sink stays reactive to external system changes. */
    PwObjectTracker {
        objects: root.activeSink ? [root.activeSink] : []
    }

    // --- Tray State Management ---
    property bool isTrayExpanded: false

    Row {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 12

        // --- System Tray Module ---
        Row {
            id: trayModule
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            // Collapsible container for tray items
            Item {
                id: trayContainer
                height: contentLayout.height
                width: root.isTrayExpanded ? trayContent.width : 0
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }

                Row {
                    id: trayContent
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    spacing: 8

                    Repeater {
                        model: SystemTray.items

                        delegate: Rectangle {
                            id: trayItemRect
                            width: 20
                            height: 20
                            color: "transparent"
                            radius: 4

                            required property var modelData

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.on_surface
                                opacity: trayItemHover.hovered ? 0.1 : 0
                                radius: 4
                            }

                            Image {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: modelData.icon
                                sourceSize: Qt.size(14, 14)
                            }

                            HoverHandler {
                                id: trayItemHover
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onTapped: (eventPoint, button) => {
                                    if (button === Qt.LeftButton) {
                                        modelData.activate();
                                    } else if (button === Qt.RightButton) {
                                        if (modelData.hasMenu) {
                                            customTrayMenu.trayItem = modelData;
                                            customTrayMenu.openFor(trayItemRect);
                                        } else {
                                            modelData.secondaryActivate();
                                        }
                                    }
                                }
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            TrayMenu {
                id: customTrayMenu
                parentWindow: root.panelWindow
            }

            // Toggle Arrow
            Text {
                id: trayToggleIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pointSize: 10
                }
                color: trayToggleHover.hovered ? Theme.primary : Theme.on_surface_variant
                text: "" // Angle left
                rotation: root.isTrayExpanded ? 180 : 0
                transformOrigin: Item.Center

                Behavior on rotation {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.InOutQuad
                    }
                }

                HoverHandler {
                    id: trayToggleHover
                }

                TapHandler {
                    onTapped: root.isTrayExpanded = !root.isTrayExpanded
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        // --- Separator ---
        Rectangle {
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Audio Module ---
        Row {
            id: volumeModule
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: volumeIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pointSize: 10
                }
                color: root.isMuted ? Theme.critical : Theme.primary

                text: {
                    if (!root.activeSink?.audio)
                        return ""; // No device
                    if (root.isMuted)
                        return ""; // Muted
                    if (root.volumeLevel >= 0.6)
                        return ""; // High
                    if (root.volumeLevel >= 0.3)
                        return ""; // Mid
                    return "";     // Low
                }
            }

            Text {
                id: volumeLabel
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.on_surface
                font {
                    family: "Google Sans Medium"
                    pointSize: 10
                }
                text: root.activeSink?.audio ? Math.round(root.volumeLevel * 100) + "%" : "--%"
            }

            TapHandler {
                onTapped: if (root.activeSink?.audio)
                    root.activeSink.audio.muted = !root.isMuted
                cursorShape: Qt.PointingHandCursor
            }
        }

        // --- Separator ---
        Rectangle {
            visible: batteryModule.isVisible
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Battery Module ---
        Row {
            id: batteryModule
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool isVisible: UPower.displayDevice?.isPresent ?? false
            readonly property real capacity: (UPower.displayDevice?.percentage ?? 0) * 100
            readonly property bool isCharging: !UPower.onBattery

            visible: isVisible

            Text {
                id: batteryIcon
                anchors.verticalCenter: parent.verticalCenter
                font {
                    family: "JetBrainsMono Nerd Font"
                    pointSize: 10
                }

                color: (batteryModule.isCharging && batteryModule.capacity < 100) || batteryModule.capacity <= 20 ? Theme.critical : Theme.primary

                text: {
                    if (!batteryModule.isVisible)
                        return "";
                    // charging capacity icons
                    if (batteryModule.isCharging && batteryModule.capacity < 10)
                        return "󰢜";
                    if (batteryModule.isCharging && batteryModule.capacity < 20)
                        return "󰂆";
                    if (batteryModule.isCharging && batteryModule.capacity < 30)
                        return "󰂇";
                    if (batteryModule.isCharging && batteryModule.capacity < 40)
                        return "󰂈";
                    if (batteryModule.isCharging && batteryModule.capacity < 50)
                        return "󰢝";
                    if (batteryModule.isCharging && batteryModule.capacity < 60)
                        return "󰂉";
                    if (batteryModule.isCharging && batteryModule.capacity < 70)
                        return "󰢞";
                    if (batteryModule.isCharging && batteryModule.capacity < 80)
                        return "󰂊";
                    if (batteryModule.isCharging && batteryModule.capacity < 90)
                        return "󰂋";
                    if (batteryModule.isCharging && batteryModule.capacity <= 100)
                        return "󰂅";

                    // on battery capacity icons
                    if (batteryModule.capacity < 10)
                        return "󰁺";
                    if (batteryModule.capacity < 20)
                        return "󰁻";
                    if (batteryModule.capacity < 30)
                        return "󰁼";
                    if (batteryModule.capacity < 40)
                        return "󰁽";
                    if (batteryModule.capacity < 50)
                        return "󰁾";
                    if (batteryModule.capacity < 60)
                        return "󰁿";
                    if (batteryModule.capacity < 70)
                        return "󰂀";
                    if (batteryModule.capacity < 80)
                        return "󰂁";
                    if (batteryModule.capacity < 90)
                        return "󰂂";
                    if (batteryModule.capacity <= 100)
                        return "󰁹";
                    return "󰂃";
                }
            }

            Text {
                id: batteryLabel
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.on_surface
                font {
                    family: "Google Sans Medium"
                    pointSize: 10
                }
                text: Math.round(batteryModule.capacity) + "%"
            }

            HoverHandler {
                id: batteryHover
            }

            TapHandler {
                onTapped: {
                    getProfileProc.running = true;
                    var mapped = batteryModule.mapToItem(root.panelWindow.contentItem, 0, 0);
                    powerProfileMenu.anchor.rect.x = mapped.x;
                    powerProfileMenu.anchor.rect.y = mapped.y + batteryModule.height + 6;
                    powerProfileMenu.visible = true;
                    profileFocusGrab.active = true;
                }
                cursorShape: Qt.PointingHandCursor
            }
        }

        // --- Separator ---
        Rectangle {
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Screen Record Indicator ---
        Item {
            id: screenRecIndicator
            visible: ControlPanelService.screenRecordingActive
            width: visible ? recRow.implicitWidth + 16 : 0
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            Behavior on width {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.height / 2
                color: Theme.critical
                opacity: 0.15
            }

            Row {
                id: recRow
                anchors.centerIn: parent
                spacing: 6

                // Blinking Dot
                Rectangle {
                    width: 8; height: 8
                    radius: 4
                    color: Theme.critical
                    anchors.verticalCenter: parent.verticalCenter
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: screenRecIndicator.visible && !ControlPanelService.screenRecordingPaused
                        NumberAnimation { to: 0.2; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }
                    opacity: ControlPanelService.screenRecordingPaused ? 0.4 : 1.0
                }

                // Elapsed Time
                Text {
                    text: ControlPanelService.screenRecordingElapsedText
                    font {
                        family: "Google Sans Medium"
                        pointSize: 10
                    }
                    color: Theme.critical
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler {
                id: recHover
            }

            TapHandler {
                onTapped: {
                    if (root.panelWindow) {
                        ControlPanelService.panelOpen = true;
                    }
                }
                cursorShape: Qt.PointingHandCursor
            }
        }

        // --- Notification History Button ---
        Item {
            id: notifHistoryBtn
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool hasNotifs: NotifHistoryService.allNotifications.length > 0
            readonly property bool isOpen: NotifHistoryService.panelOpen

            // Background highlight
            Rectangle {
                anchors.fill: parent
                radius: parent.height / 2
                color: notifBtnHover.containsMouse || notifHistoryBtn.isOpen ? Theme.primary_container : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }

            // Bell icon
            Text {
                anchors.centerIn: parent
                text: NotifHistoryService.dndEnabled ? "󰂛" : (notifHistoryBtn.isOpen || notifHistoryBtn.hasNotifs ? "󰂚" : "󰂜")
                font {
                    family: "JetBrainsMono Nerd Font"
                    pointSize: 12
                }
                color: notifHistoryBtn.isOpen ? Theme.on_primary_container : (NotifHistoryService.dndEnabled ? Theme.on_surface_variant : (notifHistoryBtn.hasNotifs ? Theme.primary : Theme.on_surface_variant))
                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }

            // Unread count badge
            Rectangle {
                visible: notifHistoryBtn.hasNotifs && !notifHistoryBtn.isOpen && !NotifHistoryService.dndEnabled
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: 1
                    rightMargin: 1
                }
                width: Math.max(14, badgeCount.implicitWidth + 6)
                height: 14
                radius: 7
                color: Theme.critical

                Text {
                    id: badgeCount
                    anchors.centerIn: parent
                    text: NotifHistoryService.allNotifications.length > 99 ? "99+" : NotifHistoryService.allNotifications.length
                    font {
                        family: "Google Sans Medium"
                        pixelSize: 8
                        bold: true
                    }
                    color: Theme.on_critical
                }
            }

            HoverHandler {
                id: notifBtnHover
            }

            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: NotifHistoryService.panelOpen = !NotifHistoryService.panelOpen
            }
        }
    }

    PopupWindow {
        id: powerProfileMenu
        anchor.window: root.panelWindow
        anchor.rect: Qt.rect(0, 0, 1, 1)

        visible: false
        color: "transparent"
        implicitWidth: profileSurface.implicitWidth
        implicitHeight: profileSurface.implicitHeight

        property string activePowerProfile: ""

        HyprlandFocusGrab {
            id: profileFocusGrab
            windows: [powerProfileMenu]
            active: false
            onCleared: {
                powerProfileMenu.visible = false;
                profileFocusGrab.active = false;
            }
        }

        Rectangle {
            id: profileSurface
            implicitWidth: 160
            implicitHeight: profileCol.implicitHeight + 12
            color: Theme.surface_container_high
            radius: 12
            border.color: Theme.surface_container_highest
            border.width: 1

            opacity: powerProfileMenu.visible ? 1.0 : 0.0
            scale: powerProfileMenu.visible ? 1.0 : 0.94
            transformOrigin: Item.Top

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuart
                }
            }

            Column {
                id: profileCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 6
                    bottomMargin: 6
                }
                spacing: 0

                Repeater {
                    model: [
                        {
                            label: "Performance",
                            icon: "󰓅",
                            profile: "performance"
                        },
                        {
                            label: "Balanced",
                            icon: "󰗑",
                            profile: "balanced"
                        },
                        {
                            label: "Power Saver",
                            icon: "󰌪",
                            profile: "power-saver"
                        }
                    ]

                    delegate: Item {
                        width: profileCol.width
                        height: 36

                        readonly property bool isActive: modelData.profile === powerProfileMenu.activePowerProfile

                        Rectangle {
                            anchors {
                                fill: parent
                                leftMargin: 4
                                rightMargin: 4
                            }
                            radius: 8
                            color: isActive ? Theme.primary_container : Theme.primary
                            opacity: isActive ? 1.0 : (profileHover.hovered ? 0.12 : 0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 80
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        Row {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                right: parent.right
                                leftMargin: 14
                                rightMargin: 14
                            }
                            spacing: 8

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.icon
                                color: isActive ? Theme.on_primary_container : Theme.on_surface
                                font {
                                    family: "JetBrainsMono Nerd Font"
                                    pixelSize: 14
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: isActive ? Theme.on_primary_container : Theme.on_surface
                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 13
                                }
                            }
                        }

                        HoverHandler {
                            id: profileHover
                        }

                        TapHandler {
                            onTapped: {
                                setProfileProc.targetProfile = modelData.profile;
                                setProfileProc.running = true;
                                powerProfileMenu.visible = false;
                                profileFocusGrab.active = false;
                            }
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }

    Process {
        id: getProfileProc
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var output = text.trim();
                if (output !== "") {
                    powerProfileMenu.activePowerProfile = output;
                }
            }
        }
    }

    Process {
        id: setProfileProc
        property string targetProfile: ""
        command: ["powerprofilesctl", "set", targetProfile]
        running: false
        onRunningChanged: {
            if (!running && targetProfile !== "") {
                powerProfileMenu.activePowerProfile = targetProfile;
            }
        }
    }
}
