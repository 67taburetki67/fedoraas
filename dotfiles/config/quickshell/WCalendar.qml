import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.5, Math.min(width / 310, height / 400))
  readonly property real m: 16 * u
  readonly property real evH: height > 300 ? 62 * u : 0
  readonly property real gridY: m + 46 * u
  readonly property real rowH: Math.max(14, (height - gridY - evH - m) / 6)
  readonly property real cw: (width - 2 * m) / 7
  readonly property int firstDay: (new Date(sh.now.getFullYear(), sh.now.getMonth(), 1).getDay() + 6) % 7
  readonly property int dim: new Date(sh.now.getFullYear(), sh.now.getMonth() + 1, 0).getDate()
  readonly property string ym: sh.now.getFullYear() + "-" + (sh.now.getMonth() < 9 ? "0" : "") + (sh.now.getMonth() + 1) + "-"

  WTxt { x: w.m; y: w.m; text: w.sh.months[w.sh.now.getMonth()] + " " + w.sh.now.getFullYear(); font.pixelSize: 16 * w.u }
  Repeater {
    model: w.sh.weekdays
    WTxt {
      x: w.m + index * w.cw
      y: w.m + 26 * w.u
      width: w.cw
      horizontalAlignment: Text.AlignHCenter
      text: modelData
      color: Theme.muted
      font.pixelSize: 12 * w.u
    }
  }
  Repeater {
    model: 42
    Item {
      x: w.m + (index % 7) * w.cw
      y: w.gridY + Math.floor(index / 7) * w.rowH
      width: w.cw
      height: w.rowH
      readonly property int d: index - w.firstDay + 1
      readonly property bool valid: d >= 1 && d <= w.dim
      readonly property bool isToday: valid && d === w.sh.now.getDate()
      readonly property bool hasEv: valid && w.sh.evKeys[w.ym + (d < 10 ? "0" + d : d)] === true
      Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.82
        height: width
        radius: width / 2
        color: Theme.fg
        visible: parent.isToday
      }
      WTxt {
        anchors.centerIn: parent
        text: parent.valid ? parent.d : ""
        color: parent.isToday ? Theme.bg : Theme.dim
        font.pixelSize: Math.max(8, Math.min(parent.width, parent.height) * 0.42)
      }
      Rectangle {
        visible: parent.hasEv
        width: 5 * w.u
        height: width
        radius: width / 2
        color: parent.isToday ? Theme.bg : Theme.fg
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
      }
    }
  }
  Column {
    visible: w.evH > 0
    x: w.m
    y: w.height - w.evH - w.m + 6 * w.u
    width: w.width - 2 * w.m
    spacing: 2
    WTxt { text: w.sh.upcoming.length > 0 ? "ближайшее" : "событий нет (events.txt)"; color: Theme.muted; font.pixelSize: 11 * w.u }
    Repeater {
      model: w.sh.upcoming
      WTxt {
        width: parent.width
        elide: Text.ElideRight
        text: modelData.date.slice(8, 10) + "." + modelData.date.slice(5, 7) + "  " + modelData.text
        color: Theme.dim
        font.pixelSize: 12 * w.u
      }
    }
  }
}
