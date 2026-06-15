pragma Singleton

import QtQuick

/**
 * Singleton service that stores the full notification history.
 * All received notifications are stored here, organized per-app.
 */
QtObject {
    id: root

    // --- Configuration ---
    /** Number of recent notifications to show in the "latest" section. */
    readonly property int latestCount: 7

    // --- State ---
    property bool panelOpen: false

    /** When true, incoming notification popups are suppressed (Do Not Disturb). */
    property bool dndEnabled: false

    // --- Storage ---
    /**
     * Flat list of all notifications received, newest first.
     * Each entry is a plain JS object with snapshot fields.
     */
    property var allNotifications: []

    /**
     * Derived: grouped by appName for the app-wise view.
     * Returns an array of { appName, icon, notifications[] }
     */
    readonly property var groupedByApp: {
        let map = {};
        let order = [];
        for (let i = 0; i < allNotifications.length; i++) {
            let n = allNotifications[i];
            let app = n.appName || "Unknown";
            if (!map[app]) {
                map[app] = { appName: app, icon: n.icon, notifications: [] };
                order.push(app);
            }
            map[app].notifications.push(n);
        }
        return order.map(a => map[a]);
    }

    /**
     * Add a new notification snapshot to history.
     */
    function addNotification(notification) {
        let snapshot = {
            id: notification.id,
            appName: notification.appName || "Notification",
            summary: notification.summary || "",
            body: notification.body || "",
            icon: notification.image || notification.appIcon || "",
            timestamp: new Date(),
        };

        // Remove any existing entry with the same id (replace/update)
        let existing = allNotifications.filter(n => n.id !== snapshot.id);
        allNotifications = [snapshot, ...existing];
    }

    /**
     * Clear all stored notification history.
     */
    function clearAll() {
        allNotifications = [];
    }

    /**
     * Remove a specific notification by id.
     */
    function removeById(id) {
        allNotifications = allNotifications.filter(n => n.id !== id);
    }
}
