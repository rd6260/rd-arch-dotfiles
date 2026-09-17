import Quickshell
import QtQuick
import "../../theme"

/**
 * Minimalist application launcher UI.
 * Centered floating panel with instant search and smooth list.
 */
Item {
    id: panelRoot

    width: 480
    height: 420

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    Connections {
        target: AppLauncherService
        function onPanelOpenChanged() {
            if (AppLauncherService.panelOpen) {
                searchInput.text = "";
                searchInput.forceActiveFocus();
                listView.currentIndex = 0;
            }
        }
    }

    ScriptModel {
        id: filteredApps
        values: {
            let query = searchInput.text.toLowerCase().trim();
            let allApps = DesktopEntries.applications.values;
            if (query === "") {
                return [...allApps].sort((a, b) => a.name.localeCompare(b.name));
            }
            return [...allApps]
                .filter(app => {
                    let n = (app.name || "").toLowerCase();
                    let c = (app.comment || "").toLowerCase();
                    let g = (app.genericName || "").toLowerCase();
                    return n.includes(query) || c.includes(query) || g.includes(query);
                })
                .sort((a, b) => {
                    let aName = (a.name || "").toLowerCase();
                    let bName = (b.name || "").toLowerCase();
                    let aStarts = aName.startsWith(query);
                    let bStarts = bName.startsWith(query);
                    if (aStarts && !bStarts) return -1;
                    if (!aStarts && bStarts) return 1;
                    return aName.localeCompare(bName);
                });
        }
    }

    // ── Background Card ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.surface_container_low
        radius: 24

        // Prevent clicks on the card from propagating to the background MouseArea
        MouseArea {
            anchors.fill: parent
            onPressed: (mouse) => { mouse.accepted = true; }
        }

        // ── Search ───────────────────────────────────────────────────────────
        Rectangle {
            id: searchBox
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            anchors.topMargin: 14
            height: 42
            radius: 12
            color: searchInput.activeFocus
                ? Theme.surface_container_high
                : Theme.surface_container
            Behavior on color { ColorAnimation { duration: 120 } }

            // Search icon
            Text {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: Theme.on_surface_variant
                font.pixelSize: 16
                opacity: 0.6
            }

            TextInput {
                id: searchInput
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                font { family: "Google Sans"; pixelSize: 14 }
                color: Theme.on_surface
                selectionColor: Theme.primary_container
                selectedTextColor: Theme.on_primary_container
                clip: true

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
                        AppLauncherService.panelOpen = false;
                        event.accepted = true;
                    }
                }
            }

            // Placeholder
            Text {
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Search…"
                font { family: "Google Sans"; pixelSize: 14 }
                color: Theme.on_surface_variant
                visible: searchInput.text === ""
                opacity: 0.4
            }
        }

        // ── App List ─────────────────────────────────────────────────────────
        Item {
            id: listContainer
            anchors.top: searchBox.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right

            ListView {
                id: listView
                anchors.fill: parent
                topMargin: 4
                bottomMargin: 4
                model: filteredApps
                spacing: 2
                clip: true
                highlightMoveDuration: 60
                highlightFollowsCurrentItem: true
                delegate: AppLauncherDelegate {}
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 6
                visible: listView.count === 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchInput.text.trim() !== "" ? "No matches" : "No applications"
                    color: Theme.on_surface_variant
                    font { family: "Google Sans"; pixelSize: 13 }
                    opacity: 0.5
                }
            }
        }
    }
}
