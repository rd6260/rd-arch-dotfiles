import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../theme"
import "../control-panel"

/**
 * Audio visualizer overlay using cava.
 * Spans all monitors via Variants. Smoothed data comes
 * directly from ControlPanelService.cavaData — each screen
 * repaints immediately when new data arrives.
 */
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: musicVis

        required property var modelData
        screen: modelData

        property bool anchorBottom: true
        property bool flipped: !anchorBottom

        implicitHeight: 200
        visible: ControlPanelService.visualizerEnabled
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            left: true
            right: true
            bottom: anchorBottom
            top: !anchorBottom
        }

        // Repaint every canvas whenever smoothed data updates
        Connections {
            target: ControlPanelService
            function onCavaDataChanged() {
                canvas.requestPaint()
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var data = ControlPanelService.cavaData
                if (data.length < 2) return

                drawMountainWave(ctx, data, true)
                drawMountainWave(ctx, data, false)
            }

            function drawMountainWave(ctx, data, isShadow) {
                if (data.length < 2) return

                var gradient = ctx.createLinearGradient(0, 0, width, height)

                gradient.addColorStop(0.0, Theme.primary)
                gradient.addColorStop(0.5, Theme.tertiary)
                gradient.addColorStop(1.0, Theme.secondary)

                ctx.beginPath()

                if (isShadow) {
                    ctx.globalAlpha = 0.25
                    ctx.save()
                    ctx.translate(0, musicVis.flipped ? 10 : -10)
                    ctx.scale(1.02, 1.05)
                } else {
                    ctx.globalAlpha = 1.0
                }

                ctx.fillStyle = gradient

                var baseY = musicVis.flipped ? 0 : height
                ctx.moveTo(0, baseY)

                var startY = musicVis.flipped
                    ? (data[0] * height)
                    : height - (data[0] * height)
                ctx.lineTo(0, startY)

                var barWidth = width / (data.length - 1)

                for (var i = 0; i < data.length - 1; i++) {
                    var xCurr = i * barWidth
                    var yCurr = musicVis.flipped
                        ? (data[i] * height)
                        : height - (data[i] * height)

                    var xNext = (i + 1) * barWidth
                    var yNext = musicVis.flipped
                        ? (data[i + 1] * height)
                        : height - (data[i + 1] * height)

                    var xMid = (xCurr + xNext) / 2
                    var yMid = (yCurr + yNext) / 2

                    ctx.quadraticCurveTo(xCurr, yCurr, xMid, yMid)
                }

                var lastX = (data.length - 1) * barWidth
                var lastY = musicVis.flipped
                    ? (data[data.length - 1] * height)
                    : height - (data[data.length - 1] * height)

                ctx.lineTo(lastX, lastY)
                ctx.lineTo(width, baseY)
                ctx.closePath()
                ctx.fill()

                if (isShadow)
                    ctx.restore()
            }
        }
    }
}