import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.55, Math.min(width / 360, height / 150))
  readonly property real m: 16 * u
  WTxt { x: w.m; y: w.m; text: "приложения"; color: Theme.dim; font.pixelSize: 13 * w.u }
  Flow {
    x: w.m
    y: w.m + 26 * w.u
    width: w.width - 2 * w.m
    spacing: 8 * w.u
    Repeater {
      model: w.sh.cfg.apps
      WPill { u: w.u; label: modelData.name; onClicked: w.sh.launch(modelData.cmd) }
    }
  }
}
