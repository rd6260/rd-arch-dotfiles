import QtQuick
import Qt5Compat.GraphicalEffects
import "../theme"

/**
 * A collapsible app group section for the notification history panel.
 * Shows app name as a header with a dropdown toggle, expanding to show
 * all notifications from that app.
 */
Item {
    id: root

    property var appData: null   // { appName, icon, notifications[] }
    property int panelWidth: 400

    width: panelWidth
    implicitHeight: headerItem.height + (expanded ? notifList.implicitHeight : 0) + 4

    property bool expanded: false

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    clip: true

    // === App Header Row ===
    Item {
        id: headerItem
        width: parent.width
        height: 44

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 16
                rightMargin: 16
            }
            height: 36
            radius: 10
            color: headerHover.containsMouse
                   ? Qt.lighter(Theme.surface_container_high, 1.05)
                   : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Item {
                id: headerContent
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                // App Icon (left side)
                Item {
                    id: appIconItem
                    width: 24
                    height: 24
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    // Fallback badge
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Theme.primary_container
                        visible: !appData || !appData.icon

                        Text {
                            anchors.centerIn: parent
                            text: appData ? (appData.appName || "?").charAt(0).toUpperCase() : "?"
                            color: Theme.on_primary_container
                            font {
                                family: "Google Sans Medium"
                                pixelSize: 12
                                bold: true
                            }
                        }
                    }

                    Rectangle {
                        id: groupIconMask
                        anchors.fill: parent
                        radius: 6
                        visible: false
                    }

                    Image {
                        anchors.fill: parent
                        source: appData ? appData.icon : ""
                        fillMode: Image.PreserveAspectFit
                        visible: !!appData && !!appData.icon
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: groupIconMask
                        }
                    }
                }

                // Expand arrow (right side)
                Text {
                    id: expandArrow
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: ""
                    font {
                        family: "JetBrainsMono Nerd Font"
                        pointSize: 9
                    }
                    color: Theme.on_surface_variant
                    rotation: root.expanded ? 90 : 0
                    transformOrigin: Item.Center
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Count badge (right of arrow)
                Rectangle {
                    id: countBadge
                    anchors {
                        right: expandArrow.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: 8
                    }
                    height: 18
                    width: Math.max(18, countText.implicitWidth + 10)
                    radius: 9
                    color: Theme.secondary_container

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: appData ? appData.notifications.length : "0"
                        font {
                            family: "Google Sans Medium"
                            pointSize: 8
                        }
                        color: Theme.on_secondary_container
                    }
                }

                // App name (between icon and count)
                Text {
                    anchors {
                        left: appIconItem.right
                        right: countBadge.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                        rightMargin: 8
                    }
                    text: appData ? appData.appName : ""
                    font {
                        family: "Google Sans Medium"
                        pointSize: 10
                    }
                    color: Theme.on_surface
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: headerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    // === Notification List (Collapsible) ===
    Column {
        id: notifList
        anchors {
            top: headerItem.bottom
            left: parent.left
            right: parent.right
        }
        spacing: 0

        Repeater {
            model: appData ? appData.notifications : []

            delegate: HistoryNotifCard {
                required property var modelData
                required property int index
                notification: modelData
                panelWidth: root.panelWidth - 8   // slight indent for grouping
                anchors.right: parent ? parent.right : undefined
                onDismissed: {
                    // Remove from the service by id
                    if (modelData) {
                        let arr = NotifHistoryService.allNotifications.filter(n => n.id !== modelData.id);
                        NotifHistoryService.allNotifications = arr;
                    }
                }
            }
        }

        // Small padding at bottom of list
        Item {
            width: parent.width
            height: 6
        }
    }
}
