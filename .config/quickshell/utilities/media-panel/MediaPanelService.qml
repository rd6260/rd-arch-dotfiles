pragma Singleton

import QtQuick

/**
 * Singleton holding state for the media panel.
 */
QtObject {
    id: root

    // --- Panel visibility ---
    property bool panelOpen: false
}
