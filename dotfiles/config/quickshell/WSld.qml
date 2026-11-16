import QtQuick

Item {
  id: s
  property real source: 0
  property real value: source
  signal moved(real v)
  height: 28
  onSourceChanged: { if (!sma.pressed) value = source }
  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 8
    radius: 4
    color: Theme.line
    Rectangle { width: track.width * s.value; height: track.height; radius: 4; color: Theme.fg }
  }
  Rectangle {
    x: Math.max(0, Math.min(s.width - width, s.width * s.value - width / 2))
    anchors.verticalCenter: parent.verticalCenter
    width: 16
    height: 16
    radius: 8
    color: Theme.bright
  }
  Timer { id: thr; interval: 130; onTriggered: s.moved(s.value) }
  MouseArea {
    id: sma
    anchors.fill: parent
    function setFrom(mx) { s.value = Math.max(0, Math.min(1, mx / s.width)) }
    onPressed: (m) => { setFrom(m.x); thr.start() }
    onPositionChanged: (m) => { if (pressed) { setFrom(m.x); if (!thr.running) thr.start() } }
    onReleased: { thr.stop(); s.moved(s.value) }
  }
}
