import QtQuick
import Quickshell.Services.Pipewire
import "../../theme"

/** An audio device (picker row + volume) with the app streams routed to it. */
Column {
    id: group
    required property var device
    required property var activeDevice
    required property bool isSinkGroup

    visible: device.isSink === isSinkGroup && !device.isStream && device.audio != null
    height: visible ? implicitHeight : 0
    width: parent ? parent.width : 320

    AudioDeviceDelegate {
        width: group.width
        device: group.device
        activeDevice: group.activeDevice
        isSink: group.isSinkGroup
    }
    SliderRow {
        width: group.width
        icon: (group.device.audio?.muted ?? false) ? "󰖁"
            : (group.device.audio?.volume ?? 0) >= 0.6 ? "󰕾"
            : (group.device.audio?.volume ?? 0) >= 0.3 ? "󰖀" : "󰕿"
        value: group.device.audio?.volume ?? 0
        active: !(group.device.audio?.muted ?? true)
        onSliderMoved: v => { if (group.device.audio) group.device.audio.volume = v; }
        onIconClicked: { if (group.device.audio) group.device.audio.muted = !group.device.audio.muted; }
    }
    Repeater {
        model: Pipewire.nodes
        delegate: StreamRow {
            required property var modelData
            stream: modelData
            device: group.device
            visible: modelData.isStream && modelData.isSink === group.isSinkGroup
                     && linkedToDevice && modelData.audio != null
        }
    }
    Item { width: 1; height: 8 }
}
