import QtQuick

Item {
  id: w
  property var sh
  readonly property real fs: Math.max(20, Math.min(height * 0.58, width * 0.2))
  Column {
    anchors.centerIn: parent
    spacing: w.fs * 0.02
    WTxt {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(w.sh.now, "HH:mm")
      font.pixelSize: w.fs
      font.weight: Font.Light
    }
    WTxt {
      anchors.horizontalCenter: parent.horizontalCenter
      text: w.sh.weekdays[(w.sh.now.getDay() + 6) % 7] + ", " + w.sh.now.getDate() + " " + w.sh.monthsGen[w.sh.now.getMonth()]
      color: Theme.dim
      font.pixelSize: Math.max(10, w.fs * 0.17)
    }
  }
}
