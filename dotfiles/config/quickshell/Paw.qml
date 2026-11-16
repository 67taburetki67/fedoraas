import QtQuick

Item {
  id: p
  width: 54
  height: 60
  opacity: 0
  scale: 0.6
  Component.onCompleted: anim.start()
  SequentialAnimation {
    id: anim
    ParallelAnimation {
      NumberAnimation { target: p; property: "opacity"; to: 0.34; duration: 350; easing.type: Easing.OutCubic }
      NumberAnimation { target: p; property: "scale"; to: 1; duration: 450; easing.type: Easing.OutBack }
    }
    PauseAnimation { duration: 3200 }
    NumberAnimation { target: p; property: "opacity"; to: 0; duration: 1600 }
  }
  Canvas {
    id: cv
    anchors.fill: parent
    onPaint: {
      const c = getContext("2d");
      c.reset();
      c.scale(width / 40, height / 44);
      c.fillStyle = Theme.fg.toString();
      const e = (x, y, rx, ry) => { c.beginPath(); c.ellipse(x - rx, y - ry, rx * 2, ry * 2); c.fill(); };
      e(20, 31, 11, 9);
      e(7, 19, 4.5, 6);
      e(15, 11, 4.5, 6.5);
      e(25, 11, 4.5, 6.5);
      e(33, 19, 4.5, 6);
    }
    Connections { target: Theme; function onFgChanged() { cv.requestPaint() } }
  }
}
