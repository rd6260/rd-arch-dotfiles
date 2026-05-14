import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: shim

    property var userModel: ListModel {
        id: internalUserModel
        property string lastUser: Quickshell.env("USER") || "traveler"
        property int lastIndex: 0
        function rowCount() {
            return count;
        }

        Component.onCompleted: {
            var u = Quickshell.env("USER") || "traveler";
            append({
                name: u,
                realName: u
            });
        }
    }

    property var sessionModel: ListModel {
        id: internalSessionModel
        property int lastIndex: 0
        function rowCount() {
            return count;
        }

        Component.onCompleted: {
            append({
                name: "Session",
                file: ""
            });
        }
    }

    Process {
        id: sessionEnumerator
        command: ["bash", "-c", "for f in /usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop; do " + "[ -f \"$f\" ] && echo \"$(grep -m1 '^Name=' \"$f\" | cut -d'=' -f2)|||$(basename \"$f\")\"; " + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                if (lines.length === 0 || lines[0] === "")
                    return;
                internalSessionModel.clear();
                var currentDesktop = (Quickshell.env("XDG_SESSION_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || "").toLowerCase();
                var bestIndex = 0;

                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split("|||");
                    if (parts.length === 2 && parts[0] !== "") {
                        internalSessionModel.append({
                            name: parts[0],
                            file: parts[1]
                        });
                        if (currentDesktop !== "" && parts[1].toLowerCase().indexOf(currentDesktop) !== -1)
                            bestIndex = i;
                    }
                }

                if (internalSessionModel.count === 0)
                    internalSessionModel.append({
                        name: "Unknown",
                        file: "unknown.desktop"
                    });
                else
                    internalSessionModel.lastIndex = bestIndex;
            }
        }
    }

    property var sddm: QtObject {
        signal loginFailed
        signal loginSucceeded

        function login(user, password, sessionIndex) {
            pam.user = user;
            pam.pendingPassword = password;
            pam.start();
        }

        function reboot() {
            Quickshell.execDetached(["systemctl", "reboot"]);
        }
        function powerOff() {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    PamContext {
        id: pam
        property string pendingPassword: ""

        onResponseRequiredChanged: {
            if (responseRequired && pendingPassword !== "") {
                respond(pendingPassword);
                pendingPassword = "";
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                shim.sddm.loginSucceeded();
                Quickshell.execDetached(["loginctl", "unlock-session"]);
            } else {
                shim.sddm.loginFailed();
            }
        }
    }

    Component.onCompleted: sessionEnumerator.running = true
}
