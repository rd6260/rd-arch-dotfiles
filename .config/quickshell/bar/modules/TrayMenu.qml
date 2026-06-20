import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.theme
import "../../theme"
import QtQuick.Controls

PopupWindow {
    id: menuPopup

    property var trayItem: null
    property var parentWindow: null
    property bool isOpening: false

    // 0 = closed, 1 = open. Drives the inner clip height only.
    // Window stays full-size so Wayland never resizes mid-animation.
    property real clipProgress: 0.0

    Behavior on clipProgress {
        NumberAnimation {
            duration: menuPopup.isOpening ? 500 : 200
            easing.type: Easing.BezierSpline
            // Open:  expressiveDefaultSpatial [0.38, 1.21, 0.22, 1] — spring overshoot
            // Close: emphasizedAccel          [0.3,  0,    0.8,  0.15] — fast ease-in
            easing.bezierCurve: menuPopup.isOpening
                ? [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
                : [0.3,  0.0,  0.8,  0.15, 1.0, 1.0]
        }
    }

    function openFor(anchorItem) {
        if (!trayItem || !trayItem.hasMenu) return

        stackView.clear()
        stackView.push(subMenuComp, { handle: trayItem.menu, isSubMenu: false })

        var mapped = anchorItem.mapToItem(parentWindow.contentItem, 0, 0)
        var centerX = mapped.x + (anchorItem.width / 2)
        anchor.rect = Qt.rect(centerX - 142, Layout.topBarHeight, 284, 1)

        clipProgress = 0.0        // reset clip (instant, no Behavior yet since isOpening=false)
        visible = true
        focusGrab.active = true
        isOpening = true          // set BEFORE clipProgress so Behavior reads correct curve
        clipProgress = 1.0
    }

    anchor.window: parentWindow
    anchor.rect: Qt.rect(0, 0, 1, 1)

    color: "transparent"
    visible: false

    // Window is always full body height — never resizes during animation.
    // The inner clipItem controls what's visible via clip:true + animated height.
    implicitWidth: 284
    implicitHeight: menuBodyRect.height

    HyprlandFocusGrab {
        id: focusGrab
        windows: [menuPopup]
        active: false
        onCleared: {
            isOpening = false
            clipProgress = 0.0
            closeTimer.start()
        }
    }

    Timer {
        id: closeTimer
        interval: 220
        repeat: false
        onTriggered: menuPopup.visible = false
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SCALE CONTAINER
    // Scales from the top edge, driven by clipProgress.
    // The spring bezier (y=1.21 overshoot) makes the menu briefly grow past
    // 100% scale then snap back — creating an organic liquid expansion effect.
    // ─────────────────────────────────────────────────────────────────────────
    Item {
        id: clipItem
        width: 284
        height: menuBodyRect.height

        transformOrigin: Item.Top
        scale: menuPopup.clipProgress
        opacity: menuPopup.clipProgress > 0 ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100 } }

        // ── FILLETS ──────────────────────────────────────────────────────────
        // Pinned at y=0 (top of clip = bar bottom edge). They are the FIRST
        // thing revealed as the clip grows, forming the liquid bar junction.
        Canvas {
            id: leftFillet
            width: 32; height: 32
            x: 0; y: 0
            property color c: Theme.surface
            onCChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = c
                ctx.beginPath()
                ctx.moveTo(width, 0)
                ctx.lineTo(width, height)
                ctx.bezierCurveTo(width, height * 0.5, width * 0.5, 0, 0, 0)
                ctx.closePath()
                ctx.fill()
            }
        }

        Canvas {
            id: rightFillet
            width: 32; height: 32
            x: 252; y: 0
            property color c: Theme.surface
            onCChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.fillStyle = c
                ctx.beginPath()
                ctx.moveTo(0, 0)
                ctx.lineTo(0, height)
                ctx.bezierCurveTo(0, height * 0.5, width * 0.5, 0, width, 0)
                ctx.closePath()
                ctx.fill()
            }
        }

        // ── MENU BODY ────────────────────────────────────────────────────────
        Rectangle {
            id: menuBodyRect
            x: 32; y: 0
            width: 220
            height: (stackView.currentItem ? stackView.currentItem.implicitHeight : 0) + 12
            color: Theme.surface
            radius: 16

            Rectangle { width: 16; height: 16; anchors.top: parent.top; anchors.left: parent.left; color: Theme.surface }
            Rectangle { width: 16; height: 16; anchors.top: parent.top; anchors.right: parent.right; color: Theme.surface }

            StackView {
                id: stackView
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 6 }
                height: currentItem ? currentItem.implicitHeight : 0
                pushEnter: Transition { NumberAnimation { duration: 0 } }
                pushExit:  Transition { NumberAnimation { duration: 0 } }
                popEnter:  Transition { NumberAnimation { duration: 0 } }
                popExit:   Transition { NumberAnimation { duration: 0 } }
            }
        }
    } // clipItem

    // ─────────────────────────────────────────────────────────────────────────
    Component {
        id: subMenuComp
        SubMenu {}
    }

    component SubMenu: Column {
        id: menuCol
        required property var handle
        property bool isSubMenu: false
        property bool shown: false

        opacity: shown ? 1.0 : 0.0
        scale:   shown ? 1.0 : 0.96

        Component.onCompleted:    shown = true
        StackView.onActivating:   shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved:      destroy()

        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }

        spacing: 0

        QsMenuOpener {
            id: opener
            menu: menuCol.handle
        }

        Item {
            visible: menuCol.isSubMenu
            width: menuCol.width
            height: visible ? 36 : 0
            Rectangle {
                anchors { fill: parent; leftMargin: 4; rightMargin: 4; bottomMargin: 4 }
                radius: 8
                color: Theme.surface_container_highest
                Row {
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 10 }
                    spacing: 8
                    Text {
                        text: "󰅁"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                        color: Theme.on_surface
                    }
                    Text {
                        text: "Back"
                        font { family: "Google Sans Medium"; pixelSize: 13 }
                        color: Theme.on_surface
                    }
                }
                HoverHandler { id: backHover }
                TapHandler { cursorShape: Qt.PointingHandCursor; onTapped: stackView.pop() }
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Theme.on_surface
                    opacity: backHover.hovered ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
            }
        }

        Item { visible: menuCol.isSubMenu; width: menuCol.width; height: visible ? 4 : 0 }

        Repeater {
            model: opener.children
            delegate: Item {
                id: entryDelegate
                required property var modelData
                width: menuCol.width
                height: modelData.isSeparator ? 9 : 36

                Rectangle { visible: modelData.isSeparator; anchors.centerIn: parent; width: parent.width - 16; height: 1; color: Theme.surface_container_highest }

                Rectangle {
                    visible: !modelData.isSeparator
                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                    radius: 8; color: Theme.primary
                    opacity: itemHover.hovered && modelData.enabled ? 0.12 : 0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }

                Row {
                    id: contentRow
                    visible: !modelData.isSeparator
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14; right: parent.right; rightMargin: modelData.hasChildren ? 32 : 14 }
                    spacing: 8
                    Image {
                        id: itemIcon
                        visible: (modelData.icon ?? "") !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16; height: 16
                        source: modelData.icon ?? ""
                        sourceSize: Qt.size(16, 16)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text ?? ""
                        color: Theme.on_surface
                        opacity: modelData.enabled ? 1.0 : 0.38
                        font { family: "Google Sans Medium"; pixelSize: 13 }
                        width: contentRow.width - (itemIcon.visible ? 24 : 0)
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: modelData.hasChildren && !modelData.isSeparator
                    anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 14 }
                    text: "󰅀"; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    color: Theme.on_surface; opacity: modelData.enabled ? 1.0 : 0.38
                }

                HoverHandler { id: itemHover }
                TapHandler {
                    enabled: !modelData.isSeparator && modelData.enabled
                    cursorShape: modelData.isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onTapped: {
                        if (modelData.hasChildren) {
                            stackView.push(subMenuComp, { handle: modelData, isSubMenu: true })
                        } else {
                            modelData.triggered()
                            isOpening = false
                            clipProgress = 0.0
                            closeTimer.start()
                            focusGrab.active = false
                        }
                    }
                }
            }
        }
    }
}
