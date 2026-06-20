import Quickshell // import the Quickshell, were PanelWindow and stuffs belong
import Quickshell.Io // import this for input output functionality
import QtQuick // native qt qml
import Qt.labs.folderlistmodel // required for list model (the wallpaper list stuff)
import Quickshell.Wayland // Quickshell's wayland functionality

// new to qml and Quickshell? Don't worry, I have commented these stuffs.

// define a panel window
PanelWindow {
    id: main // give it an id main , so we can refer it from any child of this window; child is something that is embedded inside this window
    // SHRUNK: From 450 down to 280 for a sleeker profile
    implicitHeight: 280 // height 
    implicitWidth: Screen.width // width is same as the screen width
    color: "transparent" // set transparent for a good view, thou any color applicaple
    anchors.bottom: true // set both top and bottom to false for getting a good center view. ; is window anchored to bottom of screen
    anchors.top: false // is window anchored to top of screen? if both are false, it would anchor to the center of the screen
    margins.bottom: 10 // bottom margin, from screen's bottom. Applies only if anchors.bottom is true
    margins.top: 50 // top marin, from screen's top., only if anchors.top is true

    aboveWindows: true // is it above all window? yes
    exclusionMode: "Ignore" // ignore the other windows which are not part of it.
    exclusiveZone: 1 // se the exclusive Zon, I too know nothing about it, but it has become a habit to me.

    WlrLayershell.layer: WlrLayer.Overlay // type of shell in wayland, ie the window type for this panel window is set to Overlay type, ie it is not a floating or tiled window, but like a overlay.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive // provide it the keyboard focus. This .Exclusive means, regardless of whatever windows are open, the keyboard input goes to this panel window

    FileView { // required for getting a file, reading the file, this is a child of our main
        path: Quickshell.shellPath("config.json") // get the path. here config.json should be present in same directory as shell.qml (this file)
        watchChanges: true // watch for changes in the file
        onFileChanged: reload() // if the file is changed, reload this shell, not in an ugly way, but just properties reapply.
        JsonAdapter { // as wer are gonna read the config.json file, we would require a json adapter
            id: configs // give some name for accessing it
            property string wallpaper_path // define properties, we defined string, in the config.json, it reads from there.
            property string cache_path // the cache pathis also read from the config.json
            property int    number_of_pictures: 9 // More pictures = smaller thumbnails // default read from config.json. if the value is not present, it falls back to 9
            property string border_color: "#00f2ff" // a color string, border color
        }
    }

    FolderListModel { // for fetching files from a folder.
        id: folderModel
        folder: "file://" + configs.wallpaper_path // see that now we are accessing the JsonAdapter, which has id : configs, getting it's wallpaper path
        nameFilters: ["*.png","*.jpg"] // what kind of images to get?
        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                lastWallProc.running = true;
            }
        }
    }

    Process {
        id: lastWallProc
        command: ["bash", "-c", "cat ~/.cache/wallpicker/last_wallpaper 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lastWall = this.text.trim();
                if (lastWall !== "") {
                    for (var i = 0; i < folderModel.count; i++) {
                        if (folderModel.get(i, "fileName") === lastWall) {
                            pv.highlightMoveDuration = 0;
                            pv.currentIndex = i;
                            Qt.callLater(() => { pv.highlightMoveDuration = 300; });
                            break;
                        }
                    }
                }
            }
        }
    }

    PathView { // the path view, it defines a shape, where elements are present as row
        id: pv
        anchors.fill: parent // fill the parent
        focus: true // automatically provide this one the focus
        model: folderModel // what model to use? use what we imported from labs
        
        pathItemCount: configs.number_of_pictures // again refer from the configs
        preferredHighlightBegin: 0.5 // other properties, I just googled, you google too, 
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        snapMode: PathView.SnapToItem
        highlightMoveDuration: 300 // Slightly faster for the smaller size

        property real baseWidth: width / configs.number_of_pictures

        path: Path { // Search web, I just copy pasted this one. Because I am new to qml; learn slowly :)
            startX: -pv.baseWidth; startY: pv.height / 2
            
            // SIDE: Smaller, dimmer, shorter
            PathAttribute { name: "zVal"; value: 1 }
            PathAttribute { name: "progress"; value: 0.0 } 
            PathAttribute { name: "itemOpacity"; value: 0.7 }

            PathLine { x: main.width / 2; y: pv.height / 2 }
            
            // CENTER: Full Height, Aspect Width
            PathAttribute { name: "zVal"; value: 100 }
            PathAttribute { name: "progress"; value: 1.0 } 
            PathAttribute { name: "itemOpacity"; value: 1.0 }

            PathLine { x: main.width + pv.baseWidth; y: pv.height / 2 }
            
            PathAttribute { name: "zVal"; value: 1 }
            PathAttribute { name: "progress"; value: 0.0 }
        }

        delegate: Item {
            id: delegateRoot
            
            // MATH: True aspect ratio for the center, narrow strip for the sides
            readonly property real imgAspect: (img.implicitWidth > 0) ? (img.implicitWidth / img.implicitHeight) : (16/9)
            readonly property real targetWidth: (pv.height - 10) * imgAspect
            
            width: pv.baseWidth + ((targetWidth - pv.baseWidth) * (PathView.progress || 0))
            // Sides are 120px tall, center is 270px tall
            height: 120 + ((pv.height - 130) * (PathView.progress || 0))
            
            z: PathView.zVal || 1
            opacity: PathView.itemOpacity || 1.0

            Rectangle {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                color: "transparent"
                clip: true

                Image {
                    id: img
                    anchors.fill: parent
                    // No horizontal gaps, small vertical padding for side items
                    anchors.topMargin: (1.0 - (PathView.progress || 0)) * 5
                    anchors.bottomMargin: (1.0 - (PathView.progress || 0)) * 5
                    
                    source: "file://" + configs.cache_path + model.fileName
                    fillMode: PathView.isCurrentItem ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                // Selection Border
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: PathView.isCurrentItem ? 3 : 0
                    border.color: configs.border_color
                    z: 5
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: pv.currentIndex = index
                onWheel: (wheel) => {
                    let delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
                    if (delta > 0) {
                        pv.decrementCurrentIndex();
                    } else if (delta < 0) {
                        pv.incrementCurrentIndex();
                    }
                }
            }
        }

        Keys.onPressed: function(event) { // what to do on key pressed? we have defined functions, to increment or decrement the values of index so as to move or slide the images. 
            if (event.key === Qt.Key_Right || event.key === Qt.Key_L) incrementCurrentIndex()
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) decrementCurrentIndex()
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                const path = folderModel.get(currentIndex, "filePath")
                Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), path]) // execute in detached mode, the commands.sh, through which we can set the wallpaper.
                Qt.quit() // after setting the wallpaper, quit the window
            }
            else if (event.key === Qt.Key_Escape) Qt.quit() // quit if the key is escape key.
            event.accepted = true
        }
    }
}
