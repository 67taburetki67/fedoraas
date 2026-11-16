import QtQuick

Item {
  id: w
  property var sh
  readonly property real m: Math.max(8, Math.min(width, height) * 0.07)
  Row {
    anchors.fill: parent
    anchors.margins: w.m
    spacing: w.m
    WGauge { width: (parent.width - w.m) / 2; height: parent.height; value: w.sh.cpu; label: "cpu" }
    WGauge { width: (parent.width - w.m) / 2; height: parent.height; value: w.sh.mem; label: "ram" }
  }
}
