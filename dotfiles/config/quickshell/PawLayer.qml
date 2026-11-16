import QtQuick

Item {
  id: pl
  property bool active: false
  readonly property bool run: active && Theme.paws
  property real sx: 0
  property real sy: 0
  property real ang: 0
  property int step: 0

  ListModel { id: prints }

  function nextStep() {
    if (width < 10) return;
    if (step === 0 || step > 8) {
      sx = width * (0.1 + Math.random() * 0.8);
      sy = height * (0.15 + Math.random() * 0.7);
      ang = Math.random() * 2 * Math.PI;
      step = 0;
    }
    const side = (step % 2 === 0) ? 1 : -1;
    const dist = 62 * step;
    prints.append({
      px: sx + Math.cos(ang) * dist - Math.sin(ang) * 18 * side,
      py: sy + Math.sin(ang) * dist + Math.cos(ang) * 18 * side,
      rot: ang * 180 / Math.PI + 90
    });
    step++;
    if (prints.count > 36) prints.remove(0, prints.count - 36);
  }

  Timer { interval: 420; running: pl.run; repeat: true; onTriggered: pl.nextStep() }
  Timer { interval: 9000; running: pl.run; repeat: true; onTriggered: pl.step = 0 }
  onRunChanged: { if (!run) { prints.clear(); step = 0; } }

  Repeater {
    model: prints
    delegate: Paw {
      x: px - width / 2
      y: py - height / 2
      rotation: rot
    }
  }
}
