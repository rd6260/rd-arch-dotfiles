import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.theme

PopupWindow {
    id: menuPopup

    // --- Public API ---
    property var trayItem: null
    property var parentWindow: null

    function openFor(anchorItem) {
        if (!trayItem || !trayItem.hasMenu) return
        var mapped = anchorItem.mapToItem(parentWindow.contentItem, 0, 0)
        anchor.rect.x = mapped.x
        anchor.rect.y = mapped.y + anchorItem.height + 6
        visible = true
        focusGrab.active = true
    }

    // --- Anchor ---
    anchor.window: parentWindow
    anchor.rect: Qt.rect(0, 0, 1, 1)

    visible: false
    color: "transparent"
    implicitWidth: menuSurface.implicitWidth
    implicitHeight: menuSurface.implicitHeight

    HyprlandFocusGrab {
        id: focusGrab
        windows: [menuPopup]
        active: false
        onCleared: {
            menuPopup.visible = false
            focusGrab.active = false
        }
    }

    QsMenuOpener {
        id: opener
        menu: menuPopup.visible && menuPopup.trayItem
              ? menuPopup.trayItem.menu
              : null
    }

    // --- Visual ---
    Rectangle {
        id: menuSurface
        implicitWidth: Math.max(menuCol.implicitWidth + 8, 160)
        implicitHeight: menuCol.implicitHeight + 12
        color: Theme.surface_container_high
        radius: 12
        border.color: Theme.surface_container_highest
        border.width: 1

        opacity: menuPopup.visible ? 1.0 : 0.0
        scale: menuPopup.visible ? 1.0 : 0.94
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
        }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutQuart }
        }

        Column {
            id: menuCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 6
                bottomMargin: 6
            }
            spacing: 0

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entryDelegate
                    required property var modelData
                    width: menuCol.width
                    height: modelData.isSeparator ? 9 : 36

                    Rectangle {
                        visible: modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.surface_container_highest
                    }

                    Rectangle {
                        visible: !modelData.isSeparator
                        anchors {
                            fill: parent
                            leftMargin: 4
                            rightMargin: 4
                        }
                        radius: 8
                        color: Theme.primary
                        opacity: itemHover.hovered && modelData.enabled ? 0.12 : 0

                        Behavior on opacity {
                            NumberAnimation { duration: 80 }
                        }
                    }

                    Row {
                        visible: !modelData.isSeparator
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            right: parent.right
                            leftMargin: 14
                            rightMargin: 14
                        }
                        spacing: 8

                        Image {
                            visible: (modelData.icon ?? "") !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            source: modelData.icon ?? ""
                            sourceSize: Qt.size(16, 16)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text ?? ""
                            color: Theme.on_surface
                            opacity: modelData.enabled ? 1.0 : 0.38
                            font {
                                family: "Google Sans Medium"
                                pixelSize: 13
                            }
                        }
                    }

                    HoverHandler { id: itemHover }

                    TapHandler {
                        enabled: !modelData.isSeparator && modelData.enabled
                        onTapped: {
                            modelData.triggered()
                            menuPopup.visible = false
                            focusGrab.active = false
                        }
                        cursorShape: modelData.isSeparator
                            ? Qt.ArrowCursor
                            : Qt.PointingHandCursor
                    }
                }
            }
        }
    }
}
