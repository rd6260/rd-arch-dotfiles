pragma Singleton

import Quickshell
import QtQuick

/** Global time provider for shell components. */
Singleton {
    id: root

    // Formatted strings
    // readonly property string time: Qt.formatDateTime(clock.date, "  H:mm  •  ddd  MMM d  ")
    readonly property string time: Qt.formatDateTime(clock.date, " H:mm • ddd d ")

    // Extended format: 24-hour with seconds and full date (used by Calendar toggle)
    // readonly property string timeExtended: Qt.formatDateTime(clock.date, "  HH:mm:ss  ddd  dd/MM/yyyy  ")
    readonly property string timeExtended: Qt.formatDateTime(clock.date, " HH:mm:ss • ddd dd/MM/yyyy ")

    // Reactive clock source tracking seconds.
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
