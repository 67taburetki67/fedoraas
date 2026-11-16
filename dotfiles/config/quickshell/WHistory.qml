import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.5, Math.min(width / 400, height / 200))
  readonly property real m: 16 * u

  WTxt {
    x: w.m
    y: w.m * 0.75
    text: "cpu " + w.sh.cpu + "%   ram " + w.sh.mem + "%" + (w.sh.temp > 0 ? "   " + w.sh.temp + "°C" : "")
    color: Theme.dim
    font.pixelSize: 12 * w.u
  }
  Canvas {
    id: hc
    x: w.m
    y: w.m + 22 * w.u
    width: w.width - 2 * w.m
    height: Math.max(10, w.height - y - w.m)
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      ctx.lineWidth = 1;
      ctx.strokeStyle = Theme.line.toString();
      for (let k = 1; k < 4; k++) {
        const yy = height * k / 4;
        ctx.beginPath(); ctx.moveTo(0, yy); ctx.lineTo(width, yy); ctx.stroke();
      }
      const draw = (arr, col) => {
        if (arr.length < 2) return;
        ctx.strokeStyle = col;
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.beginPath();
        for (let i = 0; i < arr.length; i++) {
          const px = width * (i + 60 - arr.length) / 59;
          const py = height * (1 - Math.min(100, arr[i]) / 100);
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        }
        ctx.stroke();
      };
      draw(w.sh.memHist, Theme.muted.toString());
      draw(w.sh.cpuHist, Theme.fg.toString());
    }
    Connections { target: w.sh; function onCpuHistChanged() { hc.requestPaint() } }
    Connections { target: Theme; function onFgChanged() { hc.requestPaint() } }
  }
}
