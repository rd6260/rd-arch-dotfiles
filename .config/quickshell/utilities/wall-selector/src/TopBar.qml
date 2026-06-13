
import QtQuick

Rectangle {
  id: topBar

  required property int animationDuration
  required property var availableColors
  required property var colorOrder
  required property var colorOrderColors
  required property string currentCardColor
  required property int currentIndex
  property real entryOffset: parent.width / 2
  required property int filteredCount
  required property bool livePreview
  required property var pluginApi
  required property string selectedColorFilter
  required property string selectedFilter
  required property real shearFactor

  signal colorFilterSelected(string key)
  signal filterSelected(string key)
  signal livePreviewToggled
  signal shuffleRequested

  function flashShuffle() {
    shuffleBtn.flash();
  }

  color: Color.mSurface

  Behavior on entryOffset {
    NumberAnimation {
      duration: topBar.animationDuration
      easing.overshoot: 1.0
      easing.type: Easing.OutBack
    }
  }

  transform: Matrix4x4 {
    property real s: topBar.shearFactor

    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
  }

  Component.onCompleted: entryOffset = 0

  // ── Inline Components ──

  component TButton: Rectangle {
    id: btn

    property color accentColor: active ? Color.mOnSurface : Color.mOnSurfaceVariant
    property bool active: false
    property string hotkey: ""
    property string icon: ""
    property string label: ""
    property bool pulsing: false

    signal clicked

    border.color: active ? Qt.alpha(accentColor, 0.5) : Qt.alpha('#49454f', 0.3)
    border.width: 1
    color: active ? Qt.alpha(accentColor, 0.15) : Qt.alpha(Color.mOnSurface, 0.06)
    height: 32
    radius: 12
    width: btnRow.width + Style.margin2M

    Behavior on border.color {
      ColorAnimation {
        duration: 150
      }
    }
    Behavior on color {
      ColorAnimation {
        duration: 150
      }
    }

    Row {
      id: btnRow

      anchors.centerIn: parent
      spacing: 8

      PulsingDot {
        anchors.verticalCenter: parent.verticalCenter
        pulsing: btn.pulsing
        visible: btn.pulsing
      }
      NIcon {
        color: btn.accentColor
        icon: btn.icon
        visible: btn.icon !== ""
      }
      NText {
        anchors.verticalCenter: parent.verticalCenter
        color: btn.accentColor
        font.pointSize: 10
        text: btn.label
        visible: btn.label !== ""
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        border.color: Qt.alpha(btn.accentColor, 0.35)
        border.width: 2
        color: Qt.alpha(btn.accentColor, 0.12)
        height: 16 + 2
        opacity: 0.25
        radius: 4
        visible: btn.hotkey !== ""
        width: 16 + 5

        Rectangle {
          anchors.bottomMargin: 2
          anchors.fill: parent
          border.color: Qt.alpha(btn.accentColor, 0.25)
          border.width: 1
          color: Qt.alpha(btn.accentColor, 0.1)
          radius: 4

          NText {
            anchors.centerIn: parent
            color: Qt.alpha(btn.accentColor, 0.7)
            font.bold: true
            font.pointSize: 8
            text: btn.hotkey
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor

      onClicked: btn.clicked()
    }
  }

  component CButton: Rectangle {
    id: colorBtn

    property bool active: false
    property bool available: true
    property bool current: false
    required property color faceColor

    signal clicked

    border.color: active ? Color.mOnSurface : Qt.alpha('#49454f', 0.3)
    border.width: 1
    color: faceColor
    height: 32
    opacity: active ? 1.0 : available ? 0.4 : 0.12
    radius: 12
    width: height

    Behavior on opacity {
      NumberAnimation {
        duration: 150
      }
    }
    Behavior on border.color {
      ColorAnimation {
        duration: 150
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -height - 2
      anchors.horizontalCenter: parent.horizontalCenter
      color: colorBtn.current ? colorBtn.faceColor : "transparent"
      height: 3
      radius: height / 2
      width: colorBtn.current ? parent.width * 0.6 : 0

      Behavior on width {
        NumberAnimation {
          duration: 150
          easing.type: Easing.OutCubic
        }
      }
      Behavior on color {
        ColorAnimation {
          duration: 150
        }
      }
    }

    NText {
      anchors.centerIn: parent
      color: Color.mOnSurface
      font.bold: true
      font.pointSize: 12
      text: topBar.pluginApi?.tr("buttons.color-na")
      visible: !colorBtn.available
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: colorBtn.available ? Qt.PointingHandCursor : Qt.ForbiddenCursor
      enabled: colorBtn.available

      onClicked: colorBtn.clicked()
    }
  }

  component SButton: Item {
    id: shuffleItem

    property string hotkey: ""
    property string icon: ""
    property string label: ""

    signal clicked

    function flash() {
      flashAnim.restart();
    }

    height: innerBtn.height
    width: innerBtn.width

    TButton {
      id: innerBtn

      hotkey: shuffleItem.hotkey
      icon: shuffleItem.icon
      label: shuffleItem.label

      onClicked: {
        shuffleItem.clicked();
        shuffleItem.flash();
      }
    }

    Rectangle {
      id: flashOverlay

      anchors.fill: innerBtn
      color: Color.mPrimary
      opacity: 0
      radius: innerBtn.radius
    }

    SequentialAnimation {
      id: flashAnim

      NumberAnimation {
        duration: 80
        easing.type: Easing.OutCubic
        property: "opacity"
        target: flashOverlay
        to: 0.3
      }
      NumberAnimation {
        duration: 300
        easing.type: Easing.OutCubic
        property: "opacity"
        target: flashOverlay
        to: 0
      }
    }
  }

  component PulsingDot: Rectangle {
    id: root

    property color dotColor: Color.mError
    property bool pulsing: false

    color: dotColor
    height: 8
    radius: 2
    width: 8

    SequentialAnimation {
      id: pulseAnimation

      loops: Animation.Infinite
      running: root.pulsing

      onRunningChanged: {
        if (!running)
          root.opacity = 1.0;
      }

      NumberAnimation {
        duration: 800
        easing.type: Easing.InOutSine
        from: 1.0
        property: "opacity"
        target: root
        to: 0.3
      }
      NumberAnimation {
        duration: 800
        easing.type: Easing.InOutSine
        from: 0.3
        property: "opacity"
        target: root
        to: 1.0
      }
    }
  }

  // ── Left ──

  NText {
    anchors.left: parent.left
    anchors.leftMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    text: (topBar.currentIndex + 1) + " / " + topBar.filteredCount
  }

  // ── Center ──

  Row {
    anchors.centerIn: parent
    spacing: 4

    Repeater {
      model: [
        {
          key: "all",
          label: topBar.pluginApi?.tr("buttons.all"),
          icon: "wallpaper",
          hotkey: "A"
        },
        {
          key: "images",
          label: topBar.pluginApi?.tr("buttons.images"),
          icon: "image",
          hotkey: "I"
        },
        {
          key: "videos",
          label: topBar.pluginApi?.tr("buttons.videos"),
          icon: "video",
          hotkey: "V"
        }
      ]

      TButton {
        required property var modelData

        active: topBar.selectedFilter === modelData.key
        hotkey: modelData.hotkey
        icon: modelData.icon
        label: modelData.label || ""

        onClicked: topBar.filterSelected(modelData.key)
      }
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(Color.mOnSurface, 0.15)
      height: parent.height * 0.5
      width: 1
    }

    Repeater {
      model: topBar.colorOrder

      CButton {
        required property int index
        required property string modelData

        active: topBar.selectedColorFilter === modelData
        anchors.verticalCenter: parent.verticalCenter
        available: topBar.availableColors.indexOf(modelData) !== -1
        current: topBar.selectedColorFilter === "" && topBar.currentCardColor === modelData
        faceColor: topBar.colorOrderColors[index]

        onClicked: {
          if (active)
            topBar.colorFilterSelected("");
          else
            topBar.colorFilterSelected(modelData);
        }
      }
    }
  }

  // ── Right ──

  Row {
    anchors.right: parent.right
    anchors.rightMargin: 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 4

    SButton {
      id: shuffleBtn

      hotkey: "R"
      icon: "arrows-random"
      label: topBar.pluginApi?.tr("buttons.shuffle")

      onClicked: topBar.shuffleRequested()
    }

    TButton {
      accentColor: topBar.livePreview ? Color.mTertiary : Color.mOnSurfaceVariant
      active: topBar.livePreview
      hotkey: "P"
      label: topBar.pluginApi?.tr("buttons.live-preview")
      pulsing: topBar.livePreview

      onClicked: topBar.livePreviewToggled()
    }
  }
}
