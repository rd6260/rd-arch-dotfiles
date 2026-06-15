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
Item {
    id: panelRoot

    // Accept keyboard focus for Escape key
    focus: true
    Keys.onEscapePressed: {
        MediaPanelService.panelOpen = false;
    }

    // ── Geometry ────────────────────────────────────────────────────────────
    // Expand to include the fillets (32px above, 32px right) for a fluid morphing curve
    width: 380 + 32
    height: 140 + 32

    // No drop shadow for the liquid aesthetic, it must be completely flat with the bezel.

    // The actual 380x140 panel container
    Item {
        id: panelBody
        width: 380
        height: 140
        anchors.bottom: parent.bottom
        anchors.left: parent.left

        // Base shape
        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            radius: 32 // Larger, more organic corner radius

            // Square corners touching edges
            Rectangle {
                width: 32; height: 32
                anchors.top: parent.top
                anchors.left: parent.left
                color: Theme.surface
            }
            Rectangle {
                width: 32; height: 32
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: Theme.surface
            }
            Rectangle {
                width: 32; height: 32
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                color: Theme.surface
            }
        }

        // Top-Left Fillet (above the panel)
        Canvas {
            width: 32; height: 32
            anchors.bottom: parent.top
            anchors.left: parent.left
            property color fillColor: Theme.surface
            onFillColorChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = fillColor;
                ctx.beginPath();
                ctx.moveTo(0, 32);
                ctx.lineTo(0, 0);
                // Fluid bezier curve for surface-tension morphing effect (Caelestia liquid style)
                ctx.bezierCurveTo(0, 16, 16, 32, 32, 32);
                ctx.lineTo(0, 32);
                ctx.closePath();
                ctx.fill();
            }
        }

        // Bottom-Right Fillet (to the right of the panel)
        Canvas {
            width: 32; height: 32
            anchors.bottom: parent.bottom
            anchors.left: parent.right
            property color fillColor: Theme.surface
            onFillColorChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = fillColor;
                ctx.beginPath();
                ctx.moveTo(0, 32);
                ctx.lineTo(0, 0);
                // Fluid bezier curve for surface-tension morphing effect (Caelestia liquid style)
                ctx.bezierCurveTo(0, 16, 16, 32, 32, 32);
                ctx.lineTo(0, 32);
                ctx.closePath();
                ctx.fill();
            }
        }

        // We use a ListView to support multiple media players, allowing swiping
        ListView {
            id: playerList
            anchors.fill: parent
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: playerList.width
                    height: playerList.height
                    radius: 32
                    
                    Rectangle {
                        width: 32; height: 32
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                    Rectangle {
                        width: 32; height: 32
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                    Rectangle {
                        width: 32; height: 32
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            }

        model: Mpris.players

        delegate: Item {
            id: playerCard
            width: playerList.width
            height: playerList.height

            required property var modelData
            property var player: modelData

            // No dynamic background overlay; let the Theme.surface background from panelBody show through perfectly to match the bezel seamlessly.

            Item {
                id: cardLayout
                anchors.fill: parent
                anchors.margins: 20

                // ── Album Art ──
                Rectangle {
                    id: artContainer
                    width: 100
                    height: 100
                    radius: 32 // More organic circular/squircle look
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
                        Item {
                            width: 36; height: 36
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: prevHover.containsMouse ? Theme.surface_container_highest : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒮" // skip-previous
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                                    color: Theme.on_surface
                                }
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
                        Item {
                            width: 48; height: 48
                            anchors.verticalCenter: parent.verticalCenter
                            
                            // Safe check for playing status (dbus/qml variants)
                            property bool isPlaying: !!player.isPlaying

                            Rectangle {
                                anchors.fill: parent
                                radius: 24
                                color: Theme.primary_container

                                // Hover overlay
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 24
                                    color: playHover.containsMouse ? Qt.alpha(Theme.on_primary_container, 0.1) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: parent.parent.isPlaying ? "󰏤" : "󰐊" // pause : play
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 }
                                    color: Theme.on_primary_container
                                }
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
                        Item {
                            width: 36; height: 36
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: nextHover.containsMouse ? Theme.surface_container_highest : "transparent"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭" // skip-next
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                                    color: Theme.on_surface
                                }
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
        } // Closes Column
    } // Closes Empty State Item
} // Closes panelBody
} // Closes panelRoot
