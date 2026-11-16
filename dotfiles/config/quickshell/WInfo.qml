import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.55, Math.min(width / 300, height / 150))
  readonly property real m: 16 * u
  Column {
    x: w.m
    y: w.m
    width: w.width - 2 * w.m
    spacing: 8 * w.u
    WTxt { text: "система"; color: Theme.dim; font.pixelSize: 13 * w.u }
    WTxt { width: parent.width; elide: Text.ElideRight; text: "диск  " + w.sh.disk; font.pixelSize: 13 * w.u }
    WTxt { width: parent.width; elide: Text.ElideRight; text: "аптайм  " + w.sh.upt; font.pixelSize: 13 * w.u }
    WTxt { width: parent.width; elide: Text.ElideRight; text: "сеть  " + w.sh.net; font.pixelSize: 13 * w.u }
  }
}
