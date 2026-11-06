import QtQuick
import "../../theme"

Item {
    id: sliderRoot

    property string icon: ""
    property real   value: 0.0 // 0.0 to 1.0
    property bool   active: true
    property string accentColor: Theme.primary
    property bool   hasArrow: false

    signal arrowClicked()
    signal sliderMoved(real value)
    signal iconClicked()
    signal dragStarted()
    signal dragFinished()

    height: 40

    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 12

        // Icon Button
        Item {
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: iconHover.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            Text {
                anchors.centerIn: parent
                text: sliderRoot.icon
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                color: sliderRoot.active ? sliderRoot.accentColor : Theme.on_surface_variant
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            HoverHandler { id: iconHover }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: sliderRoot.iconClicked()
            }
        }

        // Slider Track
        Item {
            id: trackArea
            width: parent.width - 44 - (sliderRoot.hasArrow ? 44 : 0)
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            // Background track
            Rectangle {
                anchors.fill: parent
                radius: 9
                color: Theme.surface_container_high
                
                // Hover effect
                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: mouseArea.containsMouse ? Qt.alpha(Theme.on_surface, 0.04) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }

            // Fill track
            Rectangle {
                width: Math.max(18, trackArea.width * Math.min(1.0, sliderRoot.value))
                height: 18
                radius: 9
                color: sliderRoot.active ? sliderRoot.accentColor : Theme.outline_variant
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            // Over 100%: the excess is drawn as a red bar from the left end
            Rectangle {
                visible: sliderRoot.value > 1.0
                width: Math.max(18, trackArea.width * Math.min(1.0, sliderRoot.value - 1.0))
                height: 18
                radius: 9
                color: "#ff5449"
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                
                function updateValue(mx) {
                    let val = Math.max(0.0, Math.min(1.0, mx / width));
                    sliderRoot.sliderMoved(val);
                }
                
                onPressed: mouse => {
                    sliderRoot.dragStarted();
                    updateValue(mouse.x);
                }
                onPositionChanged: mouse => {
                    if (pressed) updateValue(mouse.x);
                }
                onReleased: mouse => {
                    sliderRoot.dragFinished();
                }
            }
        }

        // Optional arrow (opens a sub page)
        Item {
            visible: sliderRoot.hasArrow
            width: 32; height: 32
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: arrowHover.containsMouse ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
            }
            Text {
                anchors.centerIn: parent
                text: "󰅂"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                color: Theme.on_surface_variant
            }
            HoverHandler { id: arrowHover }
            TapHandler {
                cursorShape: Qt.PointingHandCursor
                onTapped: sliderRoot.arrowClicked()
            }
        }
    }
}

