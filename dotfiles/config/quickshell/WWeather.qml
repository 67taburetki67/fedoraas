import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.5, Math.min(width / 340, height / 190))
  readonly property real m: 16 * u
  readonly property bool days: height > 120
  readonly property real topH: days ? height * 0.42 : height - 2 * m
  readonly property real gap: 8 * u

  WTxt {
    id: tt
    x: w.m
    y: w.m
    text: w.sh.wTemp
    font.pixelSize: Math.max(16, Math.min(w.topH, w.width * 0.17))
    font.weight: Font.Light
  }
  WTxt {
    x: tt.x + tt.width + 14 * w.u
    y: w.m
    width: Math.max(0, w.width - x - w.m)
    height: tt.height
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    text: w.sh.wCond
    color: Theme.dim
    font.pixelSize: Math.max(10, 13 * w.u)
  }
  Row {
    visible: w.days
    x: w.m
    y: w.m + w.topH
    spacing: w.gap
    Repeater {
      model: w.sh.wDays
      Rectangle {
        width: (w.width - 2 * w.m - 2 * w.gap) / 3
        height: Math.max(20, w.height - (w.m + w.topH) - w.m)
        radius: 14 * w.u
        color: Theme.surface
        border.color: Theme.line
        Column {
          anchors.centerIn: parent
          spacing: 2
          WTxt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.day; color: Theme.dim; font.pixelSize: Math.max(9, 12 * w.u) }
          WTxt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.max + "° / " + modelData.min + "°"; font.pixelSize: Math.max(10, 13 * w.u) }
          WTxt {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: modelData.desc
            color: Theme.muted
            font.pixelSize: Math.max(8, 10 * w.u)
          }
        }
      }
    }
  }
}
