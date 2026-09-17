import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Polkit
import "../../theme"

/**
 * PolkitDialogUi — the styled authentication card.
 *
 * Drives the AuthFlow lifecycle:
 *   flow.submit(password)              — send response to polkit daemon
 *   flow.cancelAuthenticationRequest() — abort the session
 *   flow.failed                        — true after a wrong password
 *   flow.responseVisible               — PAM wants visible echo (e.g. username prompt)
 *   flow.isResponseRequired            — whether the input field is needed
 *   flow.supplementaryMessage          — PAM info/error text (supplementaryIsError)
 *   flow.inputPrompt                   — what PAM is asking for ("Password:", etc.)
 */
Item {
    id: root

    property AuthFlow flow: null

    width: 420
    height: card.implicitHeight

    function focusPassword() {
        passwordInput.forceActiveFocus();
    }

    // Clear field and re-focus when PAM cycles to the next prompt
    Connections {
        target: root.flow
        enabled: root.flow !== null
        function onIsResponseRequiredChanged() {
            passwordInput.text = "";
            if (root.flow && root.flow.isResponseRequired)
                passwordInput.forceActiveFocus();
        }
    }

    // ── Drop shadow ──────────────────────────────────────────────────────────
    Rectangle {
        id: shadowSrc
        anchors.fill: card
        radius: card.radius
        color: card.color
        visible: false
    }
    DropShadow {
        anchors.fill: shadowSrc
        source: shadowSrc
        radius: 32; samples: 48
        color: "#88000000"; verticalOffset: 8
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        width: parent.width
        implicitHeight: inner.implicitHeight + 32
        radius: 24
        color: Theme.surface_container_low

        MouseArea { anchors.fill: parent; onPressed: mouse => mouse.accepted = true }

        Column {
            id: inner
            width: parent.width - 40
            anchors {
                top: parent.top; topMargin: 24
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 0

            // ── Header ───────────────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 14

                // Shield bubble
                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: Theme.primary_container
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "󰒃"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                        color: Theme.on_primary_container
                    }
                }

                Column {
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 58

                    Text {
                        text: "Authentication Required"
                        color: Theme.on_surface
                        font { family: "Google Sans Medium"; pixelSize: 15 }
                        elide: Text.ElideRight; width: parent.width
                    }

                    Text {
                        text: {
                            if (!root.flow) return "";
                            let id = root.flow.selectedIdentity;
                            return id ? ("as " + (id.name ?? "root")) : "";
                        }
                        color: Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 12 }
                        visible: text !== ""
                    }
                }
            }

            Item { width: 1; height: 16 }

            // ── Divider ──────────────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 1
                color: Theme.outline_variant; opacity: 0.4
            }

            Item { width: 1; height: 14 }

            // ── Action message ────────────────────────────────────────────────
            Text {
                width: parent.width
                text: root.flow ? root.flow.message : ""
                color: Theme.on_surface_variant
                font { family: "Google Sans"; pixelSize: 13 }
                wrapMode: Text.WordWrap
                lineHeight: 1.4
                visible: text !== ""
            }

            Item { width: 1; height: 6; visible: root.flow && root.flow.message !== "" }

            // ── Action ID badge ───────────────────────────────────────────────
            Rectangle {
                width: parent.width
                implicitHeight: actionIdText.implicitHeight + 10
                radius: 8
                color: Theme.surface_container
                visible: root.flow && root.flow.actionId !== ""

                Text {
                    id: actionIdText
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 10; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.flow ? root.flow.actionId : ""
                    color: Theme.on_surface_variant
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                    elide: Text.ElideMiddle; opacity: 0.7
                }
            }

            Item { width: 1; height: 18 }

            // ── Password / response field ─────────────────────────────────────
            Rectangle {
                id: passwordField
                width: parent.width
                height: 46
                radius: 12
                visible: root.flow !== null   // always show; PAM decides if needed
                color: passwordInput.activeFocus
                       ? Theme.surface_container_high : Theme.surface_container
                border.width: passwordInput.activeFocus ? 2 : 1
                border.color: {
                    if (root.flow && root.flow.failed) return Theme.critical;
                    return passwordInput.activeFocus ? Theme.primary : Theme.outline_variant;
                }
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Behavior on color        { ColorAnimation { duration: 120 } }

                // Lock icon
                Text {
                    id: lockIcon
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    text: "󰌾"
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                    color: {
                        if (root.flow && root.flow.failed) return Theme.critical;
                        return passwordInput.activeFocus ? Theme.primary : Theme.on_surface_variant;
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                TextInput {
                    id: passwordInput
                    anchors {
                        left: lockIcon.right; leftMargin: 10
                        right: eyeBtn.left;   rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    height: parent.height
                    verticalAlignment: TextInput.AlignVCenter
                    // responseVisible = true means PAM wants plain text (e.g. username)
                    echoMode: (root.flow && root.flow.responseVisible)
                              ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    font { family: "Google Sans"; pixelSize: 14 }
                    color: Theme.on_surface
                    selectionColor: Theme.primary_container
                    selectedTextColor: Theme.on_primary_container
                    clip: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.flow && text.length > 0) {
                                root.flow.submit(text);
                                text = "";
                                forceActiveFocus();
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            if (root.flow) root.flow.cancelAuthenticationRequest();
                            event.accepted = true;
                        }
                    }
                }

                // Placeholder
                Text {
                    anchors { left: lockIcon.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: root.flow
                          ? (root.flow.inputPrompt !== "" ? root.flow.inputPrompt : "Enter password…")
                          : "Enter password…"
                    font { family: "Google Sans"; pixelSize: 14 }
                    color: Theme.on_surface_variant; opacity: 0.45
                    visible: passwordInput.text === "" && !passwordInput.activeFocus
                }

                // Eye toggle — only when PAM wants hidden input
                Item {
                    id: eyeBtn
                    width: 36; height: 36
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    visible: !(root.flow && root.flow.responseVisible)

                    Rectangle {
                        anchors.fill: parent; radius: 18
                        color: eyeHover.containsMouse
                               ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: passwordInput.echoMode === TextInput.Normal ? "󰈈" : "󰈉"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                        color: Theme.on_surface_variant
                    }
                    HoverHandler { id: eyeHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: passwordInput.echoMode =
                            passwordInput.echoMode === TextInput.Password
                            ? TextInput.Normal : TextInput.Password
                    }
                }
            }

            Item { width: 1; height: 8 }

            // ── Feedback row — failed / supplementaryMessage ──────────────────
            Item {
                width: parent.width
                height: feedbackRow.visible ? feedbackRow.implicitHeight + 6 : 0
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

                Row {
                    id: feedbackRow
                    spacing: 6
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }

                    // Wrong password
                    visible: (root.flow && root.flow.failed) ||
                             (root.flow && root.flow.supplementaryMessage !== "")

                    Text {
                        text: (root.flow && root.flow.supplementaryIsError) || (root.flow && root.flow.failed)
                              ? "󰀨" : "󰋼"
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                        color: (root.flow && (root.flow.failed || root.flow.supplementaryIsError))
                               ? Theme.critical : Theme.tertiary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: {
                            if (!root.flow) return "";
                            if (root.flow.failed && root.flow.supplementaryMessage === "")
                                return "Incorrect password. Try again.";
                            return root.flow.supplementaryMessage;
                        }
                        color: (root.flow && (root.flow.failed || root.flow.supplementaryIsError))
                               ? Theme.critical : Theme.on_surface_variant
                        font { family: "Google Sans"; pixelSize: 12 }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item { width: 1; height: 16 }

            // ── Buttons ───────────────────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 10
                layoutDirection: Qt.RightToLeft

                // Authenticate
                Rectangle {
                    width: 120; height: 40; radius: 12
                    color: authHover.containsMouse
                           ? Qt.lighter(Theme.primary, 1.08) : Theme.primary
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Authenticate"
                        color: Theme.on_primary
                        font { family: "Google Sans Medium"; pixelSize: 13 }
                    }

                    HoverHandler { id: authHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            if (root.flow && passwordInput.text.length > 0) {
                                root.flow.submit(passwordInput.text);
                                passwordInput.text = "";
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }
                }

                // Cancel
                Rectangle {
                    width: 90; height: 40; radius: 12
                    color: cancelHover.containsMouse
                           ? Qt.alpha(Theme.on_surface, 0.08) : "transparent"
                    border.width: 1; border.color: Theme.outline_variant
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Theme.on_surface_variant
                        font { family: "Google Sans Medium"; pixelSize: 13 }
                    }

                    HoverHandler { id: cancelHover }
                    TapHandler {
                        cursorShape: Qt.PointingHandCursor
                        onTapped: {
                            if (root.flow) root.flow.cancelAuthenticationRequest();
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }
        }
    }
}
