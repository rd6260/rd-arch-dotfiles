import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../../theme"

Item {
    id: panelRoot

    property string scriptPath: "$HOME/.config/quickshell/scripts/cliphist-visual.sh"
    property var allItems: []
    property var filteredItems: []

    // Width and height of the actual panel content + room for the fillets outside it
    width: 460 + 64 // 32px fillet on each side
    height: 600

    focus: true

    function updateSearch() {
        if (searchInput.text.trim() === "") {
            panelRoot.filteredItems = panelRoot.allItems;
            listView.currentIndex = 0;
            return;
        }
        let query = searchInput.text.toLowerCase();
        panelRoot.filteredItems = panelRoot.allItems.filter(item => {
            let str = item.display.toLowerCase();
            let i = 0, j = 0;
            while (i < str.length && j < query.length) {
                if (str[i] === query[j]) j++;
                i++;
            }
            return j === query.length;
        });
        listView.currentIndex = 0;
    }

    Connections {
        target: ClipboardService
        function onPanelOpenChanged() {
            if (ClipboardService.panelOpen) {
                fetchHistory.running = true;
                searchInput.text = "";
                panelRoot.forceActiveFocus();
            }
        }
    }

    Process {
        id: fetchHistory
        command: ["bash", "-c", panelRoot.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                panelRoot.allItems = this.text.split('\n').filter(line => line.trim() !== "").map(line => {
                    let parts = line.split('\t');
                    return {
                        raw: parts[0] + '\t' + (parts[1] || ""),
                        display: parts[1] || "",
                        imagePath: parts[2] || ""
                    };
                });
                panelRoot.updateSearch();
            }
        }
    }

    Process {
        id: copyToClipboard
        property string selectedItem: ""
        command: ["bash", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "_", selectedItem]
        onRunningChanged: {
            if (!running && copyToClipboard.selectedItem !== "") {
                ClipboardService.panelOpen = false;
                copyToClipboard.selectedItem = "";
            }
        }
    }

    Process {
        id: deleteEntry
        property string targetRaw: ""
        property string targetId: ""
        command: ["bash", "-c", 'printf "%s" "$1" | cliphist delete && rm -f /tmp/cliphist/"$2".*', "_", targetRaw, targetId]
        onRunningChanged: {
            if (!running && targetRaw !== "") {
                targetRaw = "";
                targetId = "";
                fetchHistory.running = true;
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_H) {
            ClipboardService.panelOpen = false;
        } else if (event.key === Qt.Key_X) {
            if (listView.currentItem) listView.currentItem.remove();
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            listView.incrementCurrentIndex();
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            listView.decrementCurrentIndex();
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_L) {
            if (listView.currentItem) listView.currentItem.select();
        } else if (event.key === Qt.Key_Slash) {
            searchInput.forceActiveFocus();
            event.accepted = true;
        }
        event.accepted = true;
    }

    // ── Main Panel Body ──────────────────────────────────────────────
    Item {
        id: panelBody
        width: 460
        height: 600
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        // Base shape
        Rectangle {
            anchors.fill: parent
            color: Theme.surface_container_low
            radius: 32 // organic corner radius

            // Square corners touching the bottom edge for the liquid morph effect
            Rectangle {
                width: 32; height: 32
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                color: Theme.surface_container_low
            }
            Rectangle {
                width: 32; height: 32
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: Theme.surface_container_low
            }
        }

        // Bottom-Left Fillet
        Canvas {
            width: 32; height: 32
            anchors.bottom: parent.bottom
            anchors.right: parent.left
            property color fillColor: Theme.surface_container_low
            onFillColorChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = fillColor;
                ctx.beginPath();
                ctx.moveTo(32, 32);
                ctx.lineTo(0, 32);
                // Fluid bezier curve
                ctx.bezierCurveTo(16, 32, 32, 16, 32, 0);
                ctx.lineTo(32, 32);
                ctx.closePath();
                ctx.fill();
            }
        }

        // Bottom-Right Fillet
        Canvas {
            width: 32; height: 32
            anchors.bottom: parent.bottom
            anchors.left: parent.right
            property color fillColor: Theme.surface_container_low
            onFillColorChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = fillColor;
                ctx.beginPath();
                ctx.moveTo(0, 32);
                ctx.lineTo(32, 32);
                // Fluid bezier curve
                ctx.bezierCurveTo(16, 32, 0, 16, 0, 0);
                ctx.lineTo(0, 32);
                ctx.closePath();
                ctx.fill();
            }
        }

        // Inner content container to handle clipping without clipping the fillets
        Item {
            anchors.fill: parent
            clip: true

            // ── Header ───────────────────────────────────────────────
            Text {
                id: headerTitle
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.topMargin: 4
                height: 44
                verticalAlignment: Text.AlignVCenter
                text: "Clipboard"
                color: Theme.on_surface
                font { family: "Google Sans Medium"; pixelSize: 15 }
            }

            Rectangle {
                anchors.top: headerTitle.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outline_variant
                opacity: 0.5
            }

            // ── Search ───────────────────────────────────────────────
            Rectangle {
                id: searchArea
                anchors.top: headerTitle.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                height: 46

                color: "transparent"

                Rectangle {
                    id: searchBox
                    anchors.fill: parent
                    anchors.margins: 8
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    radius: 10
                    color: searchInput.activeFocus
                        ? Theme.surface_container_high
                        : Theme.surface_container
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Theme.outline_variant

                    Behavior on color { ColorAnimation { duration: 120 } }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        color: Theme.on_surface
                        selectionColor: Theme.primary_container
                        selectedTextColor: Theme.on_primary_container
                        clip: true

                        onTextChanged: panelRoot.updateSearch()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                listView.incrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                listView.decrementCurrentIndex();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                if (listView.currentItem) listView.currentItem.select();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                panelRoot.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        verticalAlignment: Text.AlignVCenter
                        text: "Search…"
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        color: Theme.on_surface_variant
                        visible: searchInput.text === ""
                        opacity: 0.5
                    }
                }
            }

            Rectangle {
                id: searchDivider
                anchors.top: searchArea.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outline_variant
                opacity: 0.5
            }

            // ── List ─────────────────────────────────────────────────
            Item {
                id: listContainer
                anchors.top: searchDivider.bottom
                anchors.bottom: footerDivider.top
                anchors.left: parent.left
                anchors.right: parent.right

                ListView {
                    id: listView
                    anchors.fill: parent
                    topMargin: 6
                    bottomMargin: 6
                    model: panelRoot.filteredItems
                    spacing: 2
                    clip: true
                    highlightMoveDuration: 60
                    highlightFollowsCurrentItem: true
                    delegate: ClipboardDelegate {}
                }

                Text {
                    anchors.centerIn: parent
                    text: panelRoot.allItems.length === 0 ? "Clipboard is empty" : "No results"
                    visible: panelRoot.filteredItems.length === 0
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 13 }
                    opacity: 0.5
                }
            }

            // ── Footer ───────────────────────────────────────────────
            Rectangle {
                id: footerDivider
                anchors.bottom: footerArea.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.outline_variant
                opacity: 0.5
            }

            Item {
                id: footerArea
                anchors.bottom: parent.bottom
                width: parent.width
                height: 36

                Row {
                    anchors.centerIn: parent
                    spacing: 16

                    Repeater {
                        model: [
                            { key: "↵", hint: "copy" },
                            { key: "X", hint: "delete" },
                            { key: "/", hint: "search" },
                            { key: "Esc", hint: "close" },
                        ]
                        Row {
                            spacing: 4
                            Rectangle {
                                width: keyLabel.implicitWidth + 8
                                height: 16
                                radius: 3
                                color: Theme.surface_container_high
                                border.width: 1
                                border.color: Theme.outline_variant
                                Text {
                                    id: keyLabel
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Theme.on_surface_variant
                                    font { family: "Google Sans Medium"; pixelSize: 9 }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.hint
                                color: Theme.on_surface_variant
                                font { family: "Google Sans"; pixelSize: 10 }
                                opacity: 0.55
                            }
                        }
                    }
                }
            }
        }
    }
}
