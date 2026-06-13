import QtQuick
import Qt5Compat.GraphicalEffects
import "../theme"

/**
 * A single notification card used in the history panel.
 * Shows app icon, summary, body, and a dismiss button.
 */
Item {
    id: root

    property var notification: null
    property int panelWidth: 400

    signal dismissed()

    width: panelWidth
    height: cardRow.implicitHeight + 28
    visible: notification !== null

    // --- Shadow source ---
    Rectangle {
        id: shadowSrc
        anchors {
            fill: card
            margins: -2
        }
        radius: card.radius
        color: card.color
        visible: false
    }

    DropShadow {
        anchors.fill: shadowSrc
        source: shadowSrc
        radius: cardHover.containsMouse ? 14 : 6
        samples: 24
        color: "#44000000"
        verticalOffset: cardHover.containsMouse ? 4 : 2
        Behavior on radius { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on verticalOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    // --- Card ---
    Rectangle {
        id: card
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 16
        }
        height: cardRow.implicitHeight + 20
        radius: 12
        color: cardHover.containsMouse
               ? Qt.lighter(Theme.surface_container_high, 1.05)
               : Theme.surface_container
        border.width: 1
        border.color: Theme.outline_variant

        Behavior on color { ColorAnimation { duration: 150 } }

        scale: cardHover.pressed ? 0.985 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }

        Row {
            id: cardRow
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 12

            // App Icon
            Item {
                id: iconArea
                width: 36
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                // Fallback badge
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.primary_container
                    visible: !notification || !notification.icon

                    Text {
                        anchors.centerIn: parent
                        text: notification ? (notification.appName || "?").charAt(0).toUpperCase() : "?"
                        color: Theme.on_primary_container
                        font {
                            family: "Google Sans Medium"
                            pixelSize: 16
                            bold: true
                        }
                    }
                }

                Rectangle {
                    id: iconMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                Image {
                    anchors.fill: parent
                    source: notification ? notification.icon : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: !!notification && !!notification.icon
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: iconMask
                    }
                }
            }

            // Text block
            Column {
                id: textBlock
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - iconArea.width - dismissBtn.width - parent.spacing * 2
                spacing: 3

                Text {
                    width: parent.width
                    text: notification ? notification.appName : ""
                    color: Theme.on_surface_variant
                    font {
                        family: "Google Sans Medium"
                        pointSize: 8
                    }
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: notification ? notification.summary : ""
                    color: Theme.on_surface
                    font {
                        family: "Google Sans Medium"
                        pointSize: 10
                        bold: true
                    }
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Text {
                    width: parent.width
                    text: notification ? notification.body : ""
                    color: Theme.on_surface_variant
                    font {
                        family: "Google Sans"
                        pointSize: 9
                    }
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                // Timestamp
                Text {
                    text: notification ? formatTime(notification.timestamp) : ""
                    color: Theme.outline
                    font {
                        family: "Google Sans"
                        pointSize: 8
                    }

                    function formatTime(ts) {
                        if (!ts) return "";
                        let now = new Date();
                        let diff = Math.floor((now - ts) / 1000);
                        if (diff < 60) return "just now";
                        if (diff < 3600) return Math.floor(diff / 60) + "m ago";
                        if (diff < 86400) return Math.floor(diff / 3600) + "h ago";
                        return ts.toLocaleDateString();
                    }
                }
            }

            // Dismiss button
            Rectangle {
                id: dismissBtn
                width: 22
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: dismissHover.containsMouse ? Qt.lighter(Theme.surface_variant, 1.1) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font {
                        pixelSize: 16
                        bold: true
                    }
                    color: dismissHover.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: dismissHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: event => {
                        event.accepted = true;
                        root.dismissed();
                    }
                }
            }
        }
    }
}
