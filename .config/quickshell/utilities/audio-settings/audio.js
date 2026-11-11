.pragma library
// Helpers for classifying and labelling PipeWire nodes in the sound settings.

function prop(n, key) {
    return n && n.properties ? n.properties[key] : undefined;
}

// The combined sink and the per-device streams it creates
function isCombine(n) {
    return !!n && (n.name === "combine_bt" || String(prop(n, "node.group") ?? "").startsWith("combine-sink"));
}

function isOutputDevice(n) { return !!n && n.audio != null && n.isSink && !n.isStream && !isCombine(n); }
function isInputDevice(n)  { return !!n && n.audio != null && !n.isSink && !n.isStream; }
function isPlayback(n)     { return !!n && n.audio != null && n.isStream && n.isSink && !isCombine(n); }
function isRecording(n)    { return !!n && n.audio != null && n.isStream && !n.isSink; }

// "AA:BB:..." for Bluetooth nodes, "" otherwise
function btMac(n) {
    const m = /^bluez_(?:output|input)\.([0-9A-Fa-f_]+)/.exec(n?.name ?? "");
    return m ? m[1].replace(/_/g, ":").toUpperCase() : "";
}

// Bluetooth sink names end in a profile counter that can change between
// connections, so members are compared by device instead.
function memberKey(name) {
    const m = /^(bluez_output\.[0-9A-Fa-f_]+)\./.exec(name ?? "");
    return m ? m[1] : name;
}

function kind(n) {
    const name = n?.name ?? "";
    const desc = (n?.description ?? "").toLowerCase();
    if (prop(n, "device.api") === "bluez5" || name.startsWith("bluez_")) return "bluetooth";
    if (name.includes("hdmi") || desc.includes("hdmi") || desc.includes("displayport")) return "hdmi";
    if (prop(n, "device.bus") === "usb") return "usb";
    if (prop(n, "node.virtual")) return "virtual";
    return "builtin";
}

function icon(n, input) {
    switch (kind(n)) {
    case "bluetooth": return input ? "󰋎" : "󰋋";
    case "hdmi":      return "󰍹";
    case "virtual":   return input ? "󰍬" : "󰕾";
    default:          return input ? "󰍬" : "󰓃";
    }
}

function label(n) {
    const d = n?.description || n?.nickname || n?.name || "Unknown device";
    // "GA107 ... (HDMI) [MSI MP165 E6]" → the monitor's name
    const bracket = /\[([^\]]+)\]\s*$/.exec(d);
    if (bracket) return bracket[1];
    if (kind(n) === "builtin" && /analog/i.test(d)) return "Built-in audio";
    return d;
}

function kindLabel(n, input) {
    switch (kind(n)) {
    case "bluetooth": return "Bluetooth";
    case "hdmi":      return "HDMI / DisplayPort";
    case "usb":       return "USB";
    case "virtual":   return "Virtual device";
    default:          return input ? "Built-in input" : "Speakers & headphone jack";
    }
}

function appName(n) {
    return prop(n, "application.name") || n?.description || n?.name || "Unknown app";
}

// What the app is playing, when it says something useful
function appDetail(n) {
    const m = prop(n, "media.name") ?? "";
    const generic = ["pulse audio", "playback", "audio stream", "audiostream", "output", "record", "capture"];
    if (!m || m === appName(n) || generic.includes(m.toLowerCase())) return "";
    return m;
}

function appIconNames(n) {
    return [prop(n, "application.icon_name"), prop(n, "application.process.binary"), appName(n).toLowerCase()]
        .filter(x => !!x);
}
