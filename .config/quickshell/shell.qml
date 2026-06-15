//@ pragma UseQApplication
import Quickshell
import QtQuick
import "bar"
import "notifications"
import "utilities/clipboard"
import "utilities/control-panel"
import "utilities/media-panel"

/** Main shell entry point; manages surface orchestration. */
ShellRoot {
    id: root

    // // Primary desktop bars
    LeftBar {
        id: leftBar
    }
    BottomBar {
        id: bottomBar
    }
    RightBar {
        id: rightBar
    }

    // screen masking for rounded workspace effect
    BezelsMask {
        id: desktopBezels
    }

    // System status bar
    TopBar {
        id: topBar
    }

    // Floating notification overlay
    NotifPopup {
        id: notificationOverlay
    }

    // Notification history side panel
    NotifHistoryPanel {
        id: notifHistoryPanel
    }

    // Clipboard
    Clipboard {
        id: clipboardWindow
    }

    // Bottom-right corner control panel
    ControlPanel {
        id: controlPanel
    }

    // Bottom-left corner media panel
    MediaPanel {
        id: mediaPanel
    }
}
