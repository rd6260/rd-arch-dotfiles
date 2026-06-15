import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import Quickshell.Io
import "../../theme"
import "."

/**
 * The media panel popup content.
 * Anchored to bottom-left inside MediaPanel.qml's PanelWindow.
 */
Rectangle {
    id: panelRoot

    // Accept keyboard focus for Escape key
    focus: true
    Keys.onEscapePressed: {
        MediaPanelService.panelOpen = false;
    }

    // ── Geometry ────────────────────────────────────────────────────────────
    width: 380
    height: 140
    radius: 20
    color: Theme.surface_container_low
    border.width: 1
    border.color: Theme.outline_variant

    // ── Drop shadow ──────────────────────────────────────────────────────────
    layer.enabled: true
    layer.effect: DropShadow {
        radius: 24
        samples: 32
        color: "#88000000"
        verticalOffset: 8
    }

    // We use a ListView to support multiple media players, allowing swiping
    ListView {
        id: playerList
        anchors.fill: parent
        orientation: ListView.Horizontal
        snapMode: ListView.SnapOneItem
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        model: Mpris.players

        delegate: Item {
            id: playerCard
            width: playerList.width
            height: playerList.height

            required property var modelData
            property var player: modelData

            // Dynamic background from Album Art (blurred)
            Image {
                id: bgArt
                anchors.fill: parent
                source: player.trackArtUrl || ""
                fillMode: Image.PreserveAspectCrop
                visible: false // Used as source for blur
                asynchronous: true
            }

            FastBlur {
                anchors.fill: parent
                source: bgArt
                radius: 64
                visible: player.trackArtUrl !== undefined && String(player.trackArtUrl).trim() !== ""
                opacity: 0.25 // Subtle tint behind the UI
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.surface_container_lowest
                opacity: 0.6
                radius: 20
            }

            Item {
                id: cardLayout
                anchors.fill: parent
                anchors.margins: 20

                // ── Album Art ──
                Rectangle {
                    id: artContainer
                    width: 100
                    height: 100
                    radius: 16
                    color: Theme.surface_container_highest
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: player.trackArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: artContainer.width
                                height: artContainer.height
                                radius: artContainer.radius
                            }
                        }
                    }

                    // Fallback icon if no art
                    Text {
                        anchors.centerIn: parent
                        visible: artImage.status !== Image.Ready
                        text: "󰝚"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 40 }
                        color: Theme.on_surface_variant
                        opacity: 0.5
                    }
                }

                // ── Metadata & Controls ──
                Item {
                    anchors.left: artContainer.right
                    anchors.leftMargin: 20
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 4

                        Text {
                            text: player.trackTitle || "No Title"
                            font { family: "Google Sans Medium"; pixelSize: 18; bold: true }
                            color: Theme.on_surface
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: player.trackArtist || "Unknown Artist"
                            font { family: "Google Sans"; pixelSize: 14 }
                            color: Theme.on_surface_variant
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // ── Controls Row ──
                    Row {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        // Previous
                        Rectangle {
                            width: 36; height: 36
                            radius: 18
                            color: prevHover.containsMouse ? Theme.surface_container_highest : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮" // skip-previous
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                                color: Theme.on_surface
                            }
                            
                            MouseArea {
                                id: prevHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: player.previous()
                            }
                        }

                        // Play/Pause
                        Rectangle {
                            width: 48; height: 48
                            radius: 24
                            color: Theme.primary_container
                            anchors.verticalCenter: parent.verticalCenter
                            
                            // Safe check for playing status (dbus/qml variants)
                            property bool isPlaying: !!player.isPlaying

                            // Press/hover ripple
                            Rectangle {
                                anchors.fill: parent
                                radius: 24
                                color: playHover.containsMouse ? Qt.alpha(Theme.on_primary_container, 0.1) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: parent.isPlaying ? "󰏤" : "󰐊" // pause : play
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 }
                                color: Theme.on_primary_container
                            }

                            MouseArea {
                                id: playHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: player.togglePlaying()
                            }
                        }

                        // Next
                        Rectangle {
                            width: 36; height: 36
                            radius: 18
                            color: nextHover.containsMouse ? Theme.surface_container_highest : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭" // skip-next
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                                color: Theme.on_surface
                            }
                            
                            MouseArea {
                                id: nextHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: player.next()
                            }
                        }
                    }
                }
            }
        }
    }

    // Pagination dots (if multiple players)
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        visible: playerList.count > 1
        
        Repeater {
            model: playerList.count
            Rectangle {
                property bool isCurrent: playerList.width > 0 && Math.round(playerList.contentX / playerList.width) === index
                width: 6; height: 6
                radius: 3
                color: isCurrent ? Theme.primary : Theme.outline_variant
                opacity: isCurrent ? 1.0 : 0.5
            }
        }
    }

    // Empty state when no players are active
    Item {
        anchors.fill: parent
        visible: playerList.count === 0

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰝚"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 48 }
                color: Theme.outline_variant
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No Media Playing"
                font { family: "Google Sans Medium"; pixelSize: 16 }
                color: Theme.on_surface_variant
            }
        }
    }
}
