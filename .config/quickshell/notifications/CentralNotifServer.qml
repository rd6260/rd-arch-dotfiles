pragma Singleton

import QtQuick
import Quickshell.Services.Notifications
import "."

/**
 * Singleton service providing a centralized interface for D-Bus notification signals.
 * Also feeds all incoming notifications into NotifHistoryService for history tracking.
 */
NotificationServer {
    id: centralNotificationServer

    // Capabilities advertised to the system notification daemon
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    /**
     * Primary handler for incoming notification requests.
     * Maps external system events to the internal shell state.
     */
    onNotification: notification => {
        // Enables automatic management within the trackedNotifications ObjectModel
        notification.tracked = true;

        // Store in persistent history
        NotifHistoryService.addNotification(notification);
    }
}
