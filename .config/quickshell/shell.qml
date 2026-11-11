//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import QtQuick
import "bar"
import "notifications"
import "utilities/clipboard"
import "utilities/control-panel"
import "utilities/audio-settings"
import "utilities/media-panel"
import "utilities/app-launcher"
import "utilities/polkit"
import "utilities/visualizer"
import "utilities/sync-lyrics/qml"

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

    // Full sound settings window (opened from the control panel volume arrow)
    AudioSettings {
        id: audioSettings
    }
    // `qs ipc call sound-settings toggle` (e.g. from a keybind)
    IpcHandler {
        target: "sound-settings"
        function toggle(): void { ControlPanelService.audioSettingsOpen = !ControlPanelService.audioSettingsOpen; }
        function open(): void { ControlPanelService.audioSettingsOpen = true; }
        function close(): void { ControlPanelService.audioSettingsOpen = false; }
    }

    // Bottom-left corner media panel
    MediaPanel {
        id: mediaPanel
    }

    // App Launcher overlay
    AppLauncher {
        id: appLauncher
    }

    // PolicyKit authentication dialog
    PolkitDialog {
        id: polkitDialog
    }

    // Audio visualizer overlay (cava-based)
    Visualizer {
        id: audioVisualizer
    }

    // Synced lyrics overlay (toggleable from control panel)
    SyncLyrics {
        id: syncLyrics
    }
}
