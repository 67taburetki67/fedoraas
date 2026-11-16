import QtQuick

Item {
  id: g
  property real value: 0
  property string label: ""
  readonly property real labelH: Math.max(14, height * 0.14)
  readonly property real d: Math.max(20, Math.min(width, height - labelH))
  onValueChanged: { if (!gt.running) gt.start(); }
  Behavior on value { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
  Timer { id: gt; interval: 45; onTriggered: cv.requestPaint() }
  Canvas {
    id: cv
    width: g.d
    height: g.d
    anchors.horizontalCenter: parent.horizontalCenter
    onWidthChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      const lw = Math.max(4, width * 0.07);
      const r = width / 2 - lw;
      ctx.lineWidth = lw;
      ctx.lineCap = "round";
      ctx.strokeStyle = Theme.line.toString();
      ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI); ctx.stroke();
      ctx.strokeStyle = Theme.fg.toString();
      ctx.beginPath(); ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * g.value / 100); ctx.stroke();
    }
    Connections { target: Theme; function onFgChanged() { cv.requestPaint() } }
    WTxt { anchors.centerIn: parent; text: Math.round(g.value) + "%"; font.pixelSize: Math.max(10, g.d * 0.2) }
  }
  WTxt {
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    text: g.label
    color: Theme.dim
    font.pixelSize: Math.max(9, g.labelH * 0.7)
  }
}
