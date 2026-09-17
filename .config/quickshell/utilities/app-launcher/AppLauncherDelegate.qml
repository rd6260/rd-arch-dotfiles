import Quickshell
import QtQuick
import Qt5Compat.GraphicalEffects
import "../../theme"

Item {
    id: delegateRoot
    width: ListView.view.width
    height: 48

    property bool isSelected: ListView.isCurrentItem

    function select() {
        modelData.execute();
        AppLauncherService.panelOpen = false;
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: 12
        color: delegateRoot.isSelected ? Theme.secondary_container : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 12

            // ── Icon ────────────────────────────────────────────────
            Item {
                id: iconBox
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                // Resolve icon: Quickshell.iconPath returns a full URL string
                readonly property string resolvedIcon: {
                    if (!modelData.icon) return "";
                    return Quickshell.iconPath(modelData.icon, true);
                }

                // Circular clip mask (for fallback badge)
                Rectangle {
                    id: iconMask
                    anchors.fill: parent
                    radius: 16
                    visible: false
                }

                Image {
                    id: iconImage
                    anchors.fill: parent
                    source: iconBox.resolvedIcon
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize: Qt.size(32, 32)

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: iconMask
                    }
                }

                // Fallback: first letter badge
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    visible: iconImage.status !== Image.Ready
                    color: delegateRoot.isSelected
                        ? Theme.primary
                        : Theme.surface_container_high
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                        color: delegateRoot.isSelected
                            ? Theme.on_primary
                            : Theme.on_surface_variant
                        font { family: "Google Sans Medium"; pixelSize: 13 }
                    }
                }
            }

            // ── Name ────────────────────────────────────────────────
            Text {
                width: parent.width - iconBox.width - parent.spacing - parent.anchors.leftMargin - parent.anchors.rightMargin
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                color: delegateRoot.isSelected
                    ? Theme.on_secondary_container
                    : Theme.on_surface
                elide: Text.ElideRight
                font { family: "Google Sans Medium"; pixelSize: 13 }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: delegateRoot.ListView.view.currentIndex = index
            onClicked: delegateRoot.select()
        }
    }
}
