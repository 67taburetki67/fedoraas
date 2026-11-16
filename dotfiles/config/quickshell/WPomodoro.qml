import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.5, Math.min(width / 280, height / 170))
  Column {
    anchors.centerIn: parent
    spacing: 8 * w.u
    WTxt { anchors.horizontalCenter: parent.horizontalCenter; text: w.sh.pmNames[w.sh.pmMode]; color: Theme.dim; font.pixelSize: 13 * w.u }
    WTxt { anchors.horizontalCenter: parent.horizontalCenter; text: w.sh.fmt(w.sh.pmLeft); font.pixelSize: 44 * w.u; font.weight: Font.Light }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.max(60, w.width * 0.7)
      height: 4 * w.u
      radius: 2
      color: Theme.line
      Rectangle { width: parent.width * (1 - w.sh.pmLeft / w.sh.pmDur[w.sh.pmMode]); height: parent.height; radius: 2; color: Theme.fg }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 8 * w.u
      WPill { u: w.u; label: w.sh.pmRunning ? "пауза" : "старт"; active: w.sh.pmRunning; onClicked: w.sh.pmToggle() }
      WPill { u: w.u; label: "сброс"; onClicked: w.sh.pmSet(w.sh.pmMode) }
      WPill { u: w.u; label: "режим"; onClicked: w.sh.pmNext() }
    }
  }
}
