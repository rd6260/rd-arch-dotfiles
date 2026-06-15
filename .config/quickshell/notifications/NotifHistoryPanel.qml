import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "../theme"
import "."

/**
 * Notification history side panel, constrained within the BezelsMask workspace area.
 * Slides in from the right; slides out on close.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: historyOverlay

        required property var modelData
        screen: modelData

        // --- LayerShell Configuration ---
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notif_history_panel"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Inset within the BezelsMask workspace boundary
        margins {
            top: Layout.topBarHeight
            bottom: Layout.bottomBarHeight
            left: Layout.sideBarWidth
            right: Layout.sideBarWidth
        }

        color: "transparent"

        // --- Panel Constants ---
        readonly property int panelWidth: 400
        readonly property int headerHeight: 56
        readonly property int animDuration: 300

        // --- Visibility gating ---
        // Keep window alive until slide-out animation completes
        property bool _showing: false
        visible: _showing

        Connections {
            target: NotifHistoryService
            function onPanelOpenChanged() {
                if (NotifHistoryService.panelOpen) {
                    historyOverlay._showing = true;
                    slideInAnim.restart();
                } else {
                    slideOutAnim.restart();
                }
            }
        }

        // Close on Escape key
        Keys.onEscapePressed: NotifHistoryService.panelOpen = false

        // --- Panel slide position ---
        property real slideX: panelWidth + 32   // starts off-screen right

        NumberAnimation {
            id: slideInAnim
            target: historyOverlay
            property: "slideX"
            to: 0
            duration: historyOverlay.animDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: slideOutAnim
            target: historyOverlay
            property: "slideX"
            to: historyOverlay.panelWidth + 32
            duration: historyOverlay.animDuration
            easing.type: Easing.InCubic
            onFinished: historyOverlay._showing = false
        }

        // --- Scrim (click-to-dismiss) ---
        MouseArea {
            anchors {
                top: parent.top
                left: parent.left
                bottom: parent.bottom
                right: panelContainer.left
            }
            onClicked: NotifHistoryService.panelOpen = false
            z: 0
            // Subtle semi-transparent scrim tint
            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
                opacity: 0.18
            }
        }

        // --- Panel Container ---
        Item {
            id: panelContainer
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }
            width: historyOverlay.panelWidth
            clip: true
            z: 1

            transform: Translate {
                x: historyOverlay.slideX
            }

            // === Background ===
            Rectangle {
                id: panelBg
                anchors.fill: parent
                color: Theme.surface_container_low
                radius: 0

                // Top-left rounded corner
                Rectangle {
                    anchors.fill: parent
                    color: Theme.surface_container_low
                    radius: Layout.cornerRadius + 2
                    // Square off the right and bottom edges
                    Rectangle {
                        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                        width: Layout.cornerRadius + 2
                        color: parent.color
                    }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: Layout.cornerRadius + 2
                        color: parent.color
                    }
                }
            }

            // Subtle left border
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                width: 1
                color: Theme.outline_variant
                opacity: 0.6
            }


            // === Content ===
            Column {
                anchors.fill: parent
                spacing: 0

                // --- Header ---
                Item {
                    width: parent.width
                    height: historyOverlay.headerHeight

                    // Bottom divider
                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                            leftMargin: 16
                            rightMargin: 16
                        }
                        height: 1
                        color: Theme.outline_variant
                        opacity: 0.4
                    }

                    // Left: Bell icon + Title + Count
                    Row {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 20
                        }
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰂚"
                            font {
                                family: "JetBrainsMono Nerd Font"
                                pointSize: 15
                            }
                            color: Theme.primary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Notifications"
                            font {
                                family: "Google Sans Medium"
                                pointSize: 13
                            }
                            color: Theme.on_surface
                        }

                        // Count pill
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: NotifHistoryService.allNotifications.length > 0
                            height: 18
                            width: Math.max(22, countPillText.implicitWidth + 10)
                            radius: 9
                            color: Theme.primary_container

                            Text {
                                id: countPillText
                                anchors.centerIn: parent
                                text: NotifHistoryService.allNotifications.length
                                font {
                                    family: "Google Sans Medium"
                                    pointSize: 8
                                }
                                color: Theme.on_primary_container
                            }
                        }
                    }

                    // Right: Clear All + Close
                    Row {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 14
                        }
                        spacing: 4

                        // Clear All
                        Rectangle {
                            visible: NotifHistoryService.allNotifications.length > 0
                            height: 26
                            width: clearLabel.implicitWidth + 18
                            radius: 7
                            color: clearHover.containsMouse ? Theme.secondary_container : "transparent"
                            border.width: 1
                            border.color: clearHover.containsMouse ? "transparent" : Theme.outline_variant
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: clearLabel
                                anchors.centerIn: parent
                                text: "Clear all"
                                font { family: "Google Sans Medium"; pointSize: 9 }
                                color: clearHover.containsMouse ? Theme.on_secondary_container : Theme.on_surface_variant
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: clearHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotifHistoryService.clearAll()
                            }
                        }

                        // Close (×)
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 7
                            color: closeHover.containsMouse ? Theme.surface_container_highest : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font { pixelSize: 18; bold: true }
                                color: closeHover.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: closeHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotifHistoryService.panelOpen = false
                            }
                        }
                    }
                }

                // --- Scrollable Content ---
                Flickable {
                    id: scrollArea
                    width: parent.width
                    height: parent.height - historyOverlay.headerHeight
                    clip: true
                    contentHeight: scrollContent.implicitHeight + 20
                    contentWidth: width
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    Column {
                        id: scrollContent
                        width: parent.width
                        spacing: 0

                        // Empty State
                        Item {
                            width: parent.width
                            height: 220
                            visible: NotifHistoryService.allNotifications.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 14

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰂜"
                                    font { family: "JetBrainsMono Nerd Font"; pointSize: 40 }
                                    color: Theme.outline_variant
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No notifications"
                                    font { family: "Google Sans"; pointSize: 12 }
                                    color: Theme.outline
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Notifications will appear here"
                                    font { family: "Google Sans"; pointSize: 9 }
                                    color: Theme.outline_variant
                                }
                            }
                        }

                        // Recent Section
                        Column {
                            width: parent.width
                            spacing: 0
                            visible: NotifHistoryService.allNotifications.length > 0

                            Item {
                                width: parent.width
                                height: 38

                                Text {
                                    anchors {
                                        left: parent.left
                                        bottom: parent.bottom
                                        leftMargin: 20
                                        bottomMargin: 7
                                    }
                                    text: "RECENT"
                                    font {
                                        family: "Google Sans Medium"
                                        pointSize: 8
                                        letterSpacing: 1.5
                                    }
                                    color: Theme.primary
                                }
                            }

                            Repeater {
                                model: Math.min(NotifHistoryService.latestCount, NotifHistoryService.allNotifications.length)
                                delegate: HistoryNotifCard {
                                    required property int index
                                    notification: NotifHistoryService.allNotifications[index]
                                    panelWidth: historyOverlay.panelWidth
                                    onDismissed: NotifHistoryService.removeById(notification.id)
                                }
                            }
                        }

                        // By App Section
                        Column {
                            width: parent.width
                            spacing: 0
                            visible: NotifHistoryService.groupedByApp.length > 0

                            Item {
                                width: parent.width
                                height: 42

                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                        leftMargin: 16
                                        rightMargin: 16
                                    }
                                    height: 1
                                    color: Theme.outline_variant
                                    opacity: 0.3
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        bottom: parent.bottom
                                        leftMargin: 20
                                        bottomMargin: 7
                                    }
                                    text: "BY APP"
                                    font {
                                        family: "Google Sans Medium"
                                        pointSize: 8
                                        letterSpacing: 1.5
                                    }
                                    color: Theme.secondary
                                }
                            }

                            Repeater {
                                model: NotifHistoryService.groupedByApp
                                delegate: AppGroupSection {
                                    required property var modelData
                                    required property int index
                                    appData: modelData
                                    panelWidth: historyOverlay.panelWidth
                                }
                            }
                        }

                        Item { width: parent.width; height: 20 }
                    }
                }
            }
        }
    }
}
