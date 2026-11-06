import QtQuick
import Quickshell.Services.Pipewire
import "../../theme"

/** Volume slider for one application stream, labelled with the app name. */
Item {
    id: streamRow
    required property var stream
    required property var device
    property real indent: 14

    PwNodeLinkTracker { id: linkTracker; node: streamRow.stream }

    readonly property bool linkedToDevice: {
        let groups = linkTracker.linkGroups;
        for (let i = 0; i < groups.length; i++) {
            let lg = groups[i];
            if ((lg.source === streamRow.device && lg.target === streamRow.stream)
             || (lg.source === streamRow.stream && lg.target === streamRow.device))
                return true;
        }
        return false;
    }
    readonly property string appName: {
        let p = stream?.properties ?? {};
        return p["application.name"] || stream?.description || stream?.nickname || stream?.name || "Application";
    }

    width: parent ? parent.width : 320
    height: visible ? 58 : 0

    Text {
        x: 20 + streamRow.indent + 44
        y: 4
        width: parent.width - x - 20
        elide: Text.ElideRight
        text: streamRow.appName
        color: Theme.on_surface_variant
        font { family: "Google Sans Medium"; pixelSize: 11 }
    }
    SliderRow {
        x: streamRow.indent
        y: 18
        width: parent.width - streamRow.indent
        icon: (streamRow.stream?.audio?.muted ?? false) ? "󰖁"
            : (streamRow.stream?.audio?.volume ?? 0) >= 0.6 ? "󰕾"
            : (streamRow.stream?.audio?.volume ?? 0) >= 0.3 ? "󰖀" : "󰕿"
        value: streamRow.stream?.audio?.volume ?? 0
        active: !(streamRow.stream?.audio?.muted ?? true)
        onSliderMoved: v => { if (streamRow.stream?.audio) streamRow.stream.audio.volume = v; }
        onIconClicked: { if (streamRow.stream?.audio) streamRow.stream.audio.muted = !streamRow.stream.audio.muted; }
    }
}
