import QtQuick
import Qt5Compat.GraphicalEffects
import "../../theme"

Item {
    id: delegateRoot
    width: ListView.view.width
    height: modelData.imagePath !== "" ? 200 : 52

    property bool isSelected: ListView.isCurrentItem

    function select() {
        copyToClipboard.selectedItem = modelData.raw;
        copyToClipboard.running = true;
    }

    function remove() {
        let id = modelData.raw.split('\t')[0];
        deleteEntry.targetRaw = modelData.raw;
        deleteEntry.targetId = id;
        deleteEntry.running = true;
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 1
        anchors.bottomMargin: 1
        radius: 8
        color: delegateRoot.isSelected ? Theme.secondary_container : "transparent"

        // ── Image preview ──────────────────────────────────────
        Image {
            id: imgPreview
            visible: modelData.imagePath !== ""
            source: modelData.imagePath !== "" ? "file://" + modelData.imagePath : ""
            anchors.fill: parent
            anchors.margins: 8
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: imgPreview.width
                    height: imgPreview.height
                    radius: 6
                }
            }
        }

        // ── Text content ───────────────────────────────────────
        Text {
            visible: modelData.imagePath === ""
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: modelData.display
            textFormat: Text.PlainText
            color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font { family: "Google Sans"; pixelSize: 13 }
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
