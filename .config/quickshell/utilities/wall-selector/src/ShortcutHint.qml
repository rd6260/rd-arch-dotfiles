import QtQuick

Row {
  id: hint

  required property string keys
  required property string label

  spacing: 4

  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Repeater {
      model: hint.keys.split(" / ")

      Row {
        required property int index
        required property var modelData

        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // Separator between keys
        NText {
          anchors.verticalCenter: parent.verticalCenter
          color: Qt.alpha(Color.mOnSurface, 0.3)
          font.pointSize: 8
          text: root.pluginApi?.tr("shortcuts.key-separator")
          visible: index > 0
        }

        // Keycap
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          border.color: Qt.alpha(Color.mOnSurface, 0.2)
          border.width: 1
          color: Qt.alpha(Color.mOnSurface, 0.08)
          height: 16 + 2
          radius: 4
          width: Math.max(16 + 2, keycapText.width + 8)

          Rectangle {
            anchors.bottomMargin: 2
            anchors.fill: parent
            border.color: Qt.alpha(Color.mOnSurface, 0.15)
            border.width: 1
            color: Qt.alpha(Color.mOnSurface, 0.05)
            radius: 4

            NText {
              id: keycapText

              anchors.centerIn: parent
              color: Qt.alpha(Color.mOnSurface, 0.6)
              font.bold: true
              font.pointSize: 8
              text: modelData.trim()
            }
          }
        }
      }
    }
  }

  NText {
    anchors.verticalCenter: parent.verticalCenter
    color: Qt.alpha(Color.mOnSurface, 0.4)
    font.pointSize: 8
    text: hint.label
  }
}
