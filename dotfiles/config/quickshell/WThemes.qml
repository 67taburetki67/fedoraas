import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.55, Math.min(width / 360, height / 170))
  readonly property real m: 14 * u
  readonly property real msgH: w.sh.themeMsg !== "" ? 16 * u : 0
  readonly property real bottomH: 34 * u + 6 * u + msgH

  WTxt { id: hd; x: w.m; y: w.m; text: "тема и обои"; color: Theme.dim; font.pixelSize: 13 * w.u }
  WTxt { x: w.m + hd.width + 8 * w.u; y: w.m + 1; text: w.sh.themeList.length + " тем"; color: Theme.muted; font.pixelSize: 11 * w.u }

  Flickable {
    id: fl
    x: w.m
    y: w.m + 26 * w.u
    width: w.width - 2 * w.m
    height: Math.max(20, w.height - y - w.bottomH - w.m)
    contentWidth: width
    contentHeight: flow.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    Flow {
      id: flow
      width: fl.width - 6 * w.u
      spacing: 6 * w.u
      Repeater {
        model: w.sh.themeList
        WPill { u: w.u * 0.9; label: modelData; active: w.sh.curTheme === modelData; onClicked: w.sh.setTheme(modelData) }
      }
    }
  }
  Rectangle {
    visible: flow.height > fl.height
    x: w.width - w.m / 2 - 3
    y: fl.y + (fl.contentY / flow.height) * fl.height
    width: 3
    height: Math.max(12, fl.height * fl.height / flow.height)
    radius: 2
    color: Theme.faint
  }

  WTxt {
    visible: w.msgH > 0
    x: w.m
    y: w.height - w.m - 34 * w.u - 16 * w.u
    width: w.width - 2 * w.m
    elide: Text.ElideRight
    text: w.sh.themeMsg
    color: Theme.dim
    font.pixelSize: 11 * w.u
  }
  Row {
    x: w.m
    y: w.height - w.m - 34 * w.u
    spacing: 8 * w.u
    WPill { u: w.u; label: "следующие обои"; onClicked: w.sh.wall("next") }
    WPill { u: w.u; label: "случайные"; onClicked: w.sh.wall("random") }
  }
}
