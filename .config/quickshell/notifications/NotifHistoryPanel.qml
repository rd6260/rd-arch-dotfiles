import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../theme"
import "."

/**
 * Full-screen overlay that renders the notification history panel
 * as a right-side drawer, similar to the notification popup style.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: historyOverlay

        required property var modelData
        screen: modelData

        // --- Visibility ---
        visible: NotifHistoryService.panelOpen

        // --- LayerShell Configuration ---
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notif_history_panel"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            right: true
            bottom: true
        }

        color: "transparent"
        implicitWidth: panelWidth + 32

        // --- Panel Constants ---
        readonly property int panelWidth: 400
        readonly property int headerHeight: 56

        // Close on Escape key
        Keys.onEscapePressed: NotifHistoryService.panelOpen = false

        // --- Scrim (click-to-dismiss overlay) ---
        MouseArea {
            anchors.fill: parent
            onClicked: NotifHistoryService.panelOpen = false
            z: 0
        }

        // --- Animated Panel ---
        Item {
            id: panelSlide
            anchors {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }
            width: historyOverlay.panelWidth
            clip: false
            z: 1

            // Slide-in/out animation
            property real slideOffset: NotifHistoryService.panelOpen ? 0 : historyOverlay.panelWidth + 32
            Behavior on slideOffset {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
            transform: Translate {
                x: panelSlide.slideOffset
            }

            // --- Panel Background (Glassmorphism) ---
            Rectangle {
                id: panelBg
                anchors.fill: parent
                color: Theme.surface_container_low
                opacity: 0.97

                // Left rounded corners only
                Rectangle {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                    }
                    width: parent.width
                    radius: 16
                    color: parent.color

                    // Mask the right side to be flat
                    Rectangle {
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            right: parent.right
                        }
                        width: 16
                        color: parent.color
                    }
                }
            }

            // Subtle left border glow
            Rectangle {
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }
                width: 1
                color: Theme.outline_variant
                opacity: 0.6
            }

            // --- Content ---
            Column {
                anchors.fill: parent
                spacing: 0

                // === Header ===
                Item {
                    width: parent.width
                    height: historyOverlay.headerHeight

                    // Bottom divider
                    Rectangle {
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                            leftMargin: 20
                            rightMargin: 20
                        }
                        height: 1
                        color: Theme.outline_variant
                        opacity: 0.5
                    }

                    Row {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 24
                        }
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰂚"
                            font {
                                family: "JetBrainsMono Nerd Font"
                                pointSize: 16
                            }
                            color: Theme.primary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Notifications"
                            font {
                                family: "Google Sans Medium"
                                pointSize: 14
                            }
                            color: Theme.on_surface
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: NotifHistoryService.allNotifications.length > 0
                                  ? "(" + NotifHistoryService.allNotifications.length + ")"
                                  : ""
                            font {
                                family: "Google Sans"
                                pointSize: 11
                            }
                            color: Theme.on_surface_variant
                        }
                    }

                    // Action Buttons (Clear All + Close)
                    Row {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 16
                        }
                        spacing: 4

                        // Clear All button
                        Rectangle {
                            visible: NotifHistoryService.allNotifications.length > 0
                            height: 28
                            width: clearLabel.implicitWidth + 20
                            radius: 8
                            color: clearHover.containsMouse ? Theme.secondary_container : "transparent"
                            border.width: 1
                            border.color: clearHover.containsMouse ? "transparent" : Theme.outline_variant

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: clearLabel
                                anchors.centerIn: parent
                                text: "Clear all"
                                font {
                                    family: "Google Sans Medium"
                                    pointSize: 9
                                }
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

                        // Close button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 8
                            color: closeHover.containsMouse ? Qt.lighter(Theme.surface_variant, 1.1) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font {
                                    pixelSize: 20
                                    bold: true
                                }
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

                // === Scrollable content ===
                Flickable {
                    id: scrollArea
                    width: parent.width
                    height: parent.height - historyOverlay.headerHeight
                    clip: true
                    contentHeight: scrollContent.implicitHeight + 24
                    contentWidth: width
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }

                    Column {
                        id: scrollContent
                        width: parent.width
                        spacing: 0

                        // --- Empty State ---
                        Item {
                            width: parent.width
                            height: 200
                            visible: NotifHistoryService.allNotifications.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "󰂛"
                                    font {
                                        family: "JetBrainsMono Nerd Font"
                                        pointSize: 36
                                    }
                                    color: Theme.outline
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "No notifications"
                                    font {
                                        family: "Google Sans"
                                        pointSize: 12
                                    }
                                    color: Theme.outline
                                }
                            }
                        }

                        // --- Recent Section ---
                        Column {
                            id: recentSection
                            width: parent.width
                            spacing: 0
                            visible: NotifHistoryService.allNotifications.length > 0

                            // Section Label
                            Item {
                                width: parent.width
                                height: 40

                                Text {
                                    anchors {
                                        left: parent.left
                                        bottom: parent.bottom
                                        leftMargin: 24
                                        bottomMargin: 8
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

                        // --- App Groups Section ---
                        Column {
                            id: appGroupsSection
                            width: parent.width
                            spacing: 0
                            visible: NotifHistoryService.groupedByApp.length > 0

                            // Section Label
                            Item {
                                width: parent.width
                                height: 44

                                // Top divider
                                Rectangle {
                                    anchors {
                                        top: parent.top
                                        left: parent.left
                                        right: parent.right
                                        leftMargin: 20
                                        rightMargin: 20
                                    }
                                    height: 1
                                    color: Theme.outline_variant
                                    opacity: 0.4
                                }

                                Text {
                                    anchors {
                                        left: parent.left
                                        bottom: parent.bottom
                                        leftMargin: 24
                                        bottomMargin: 8
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

                        // Bottom padding
                        Item {
                            width: parent.width
                            height: 24
                        }
                    }
                }
            }
        }
    }
}
