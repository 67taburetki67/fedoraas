import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: pl

  property bool shown: false
  property bool demo: false
  property bool fromTop: false
  property bool cavaOk: true
  property string status: "none"
  property string artist: ""
  property string title: ""
  property string album: ""
  property string art: ""
  property real len: 0
  property real pos: 0
  property string shuffle: "Off"
  property string loopMode: "None"
  property var players: []
  property string sel: ""
  property var bars: []
  property int vol: 0
  property bool muted: false
  property var sinks: []
  property string defSink: ""
  property int volTarget: 0
  property int volSent: -1
  property real t: 0
  property var queue: []
  readonly property bool playing: status === "Playing"
  readonly property real energy: {
    if (bars.length === 0) return 0;
    let s = 0;
    for (let i = 0; i < bars.length; i++) s += bars[i];
    return s / bars.length / 100;
  }
  readonly property string ff: "JetBrains Mono"
  readonly property string home: Quickshell.env("HOME")
  readonly property string scripts: home + "/.config/quickshell/scripts"

  function fmt(s) {
    s = Math.max(0, Math.floor(s));
    const m = Math.floor(s / 60);
    const r = s % 60;
    return m + ":" + (r < 10 ? "0" : "") + r;
  }
  function sh(s) { return s.length > 18 ? s.slice(0, 17) + "…" : s; }
  function run(cmd) { queue.push(cmd); pump(); }
  function pump() {
    if (act.running || queue.length === 0) return;
    act.command = queue.shift();
    act.running = true;
  }
  function pc(args) {
    run(["playerctl"].concat(sel ? ["-p", sel] : []).concat(args));
  }
  function refresh() {
    if (!demo && !stat.running) {
      stat.command = ["bash", scripts + "/player.sh", sel];
      stat.running = true;
    }
    if (!vproc.running) vproc.running = true;
  }
  function loadSinks() { if (!sproc.running) sproc.running = true }
  function cycleSource() {
    if (players.length === 0) return;
    const i = players.indexOf(sel || players[0]);
    sel = players[(i + 1) % players.length];
    refresh();
  }
  function nextLoop() {
    const m = ["None", "Track", "Playlist"];
    return m[(m.indexOf(loopMode) + 1) % 3];
  }
  function seekFrac(f) {
    if (len <= 0) return;
    pos = f * len;
    pc(["position", String(Math.round(pos))]);
  }
  function setVol(v) {
    volTarget = Math.max(0, Math.min(100, Math.round(v)));
    vol = volTarget;
    if (!volAct.running) applyVol();
  }
  function applyVol() {
    volSent = volTarget;
    volAct.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", volSent + "%"];
    volAct.running = true;
  }
  function toggleDemo() {
    demo = !demo;
    if (demo) {
      status = "Playing"; title = "Demo Track"; artist = "Quickshell visualizer";
      album = "тест без звука"; art = ""; len = 213; pos = 42;
    } else {
      bars = []; status = "none"; refresh();
    }
  }

  onShownChanged: {
    if (shown) { refresh(); loadSinks(); }
  }

  IpcHandler {
    target: "player"
    function toggle(): void { pl.shown = !pl.shown }
    function show(): void { pl.shown = true }
    function hide(): void { pl.shown = false }
    function demoMode(): void { pl.toggleDemo(); pl.shown = true }
  }

  Process { id: act; onExited: { pl.refresh(); pl.pump(); } }
  Process { id: volAct; onExited: { if (pl.volTarget !== pl.volSent) pl.applyVol(); else pl.refresh(); } }

  Process {
    id: stat
    stdout: StdioCollector {
      onStreamFinished: {
        if (pl.demo) return;
        const m = {};
        text.split("\n").forEach(l => {
          const i = l.indexOf("=");
          if (i > 0) m[l.slice(0, i)] = l.slice(i + 1);
        });
        pl.status = m.status || "none";
        pl.artist = m.artist || "";
        pl.title = m.title || "";
        pl.album = m.album || "";
        pl.art = m.art || "";
        pl.len = (parseFloat(m.len) || 0) / 1000000;
        pl.pos = parseFloat(m.pos) || 0;
        pl.shuffle = m.shuffle || "Off";
        pl.loopMode = m.loop || "None";
        pl.players = (m.players || "").split(",").filter(x => x);
      }
    }
  }
  Process {
    id: vproc
    command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/([0-9.]+)/);
        if (!volAct.running) pl.vol = m ? Math.round(parseFloat(m[1]) * 100) : 0;
        pl.muted = text.indexOf("MUTED") >= 0;
      }
    }
  }
  Process {
    id: sproc
    command: ["bash", pl.scripts + "/audio.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const i = text.indexOf("##default");
        try {
          const j = JSON.parse(i >= 0 ? text.slice(0, i) : text);
          pl.sinks = j.map(s => ({ name: s.name, desc: s.description || s.name }));
        } catch (e) { pl.sinks = []; }
        pl.defSink = i >= 0 ? text.slice(i + 9).trim() : "";
      }
    }
  }
  Process {
    id: cava
    command: ["cava", "-p", pl.home + "/.config/quickshell/cava.conf"]
    running: pl.shown && !pl.demo
    stdout: SplitParser {
      onRead: data => {
        const p = data.split(";");
        const a = [];
        for (let i = 0; i < p.length; i++) {
          const v = parseInt(p[i]);
          if (!isNaN(v)) a.push(v);
        }
        if (a.length) { pl.bars = a; pl.cavaOk = true; }
      }
    }
    onExited: { if (pl.shown && !pl.demo) pl.cavaOk = false; }
  }

  Timer {
    interval: 700; running: pl.shown && !pl.demo; repeat: true; triggeredOnStart: true
    onTriggered: pl.refresh()
  }
  Timer {
    interval: 250; running: pl.shown && pl.playing; repeat: true
    onTriggered: pl.pos = pl.len > 0 ? Math.min(pl.len, pl.pos + 0.25) : pl.pos + 0.25
  }
  Timer {
    interval: 66; running: pl.shown && pl.demo; repeat: true
    onTriggered: {
      pl.t += 0.066;
      const a = [];
      for (let i = 0; i < 32; i++) {
        const v = 45 + 35 * Math.sin(pl.t * 3 + i * 0.5) + 15 * Math.sin(pl.t * 7.3 + i * 1.3);
        a.push(Math.max(2, Math.min(100, v)));
      }
      pl.bars = a;
    }
  }

  component Txt: Text {
    color: Theme.fg
    font.family: pl.ff
  }

  component Pill: Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    signal clicked()
    width: lbl.implicitWidth + 28
    height: 34
    radius: 13
    color: active ? Theme.fg : (pma.containsMouse ? Theme.line : Theme.surface)
    border.color: Theme.line
    Behavior on color { ColorAnimation { duration: 150 } }
    Txt {
      id: lbl
      anchors.centerIn: parent
      text: pill.label
      font.pixelSize: 13
      color: pill.active ? Theme.bg : Theme.fg
    }
    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: pill.clicked() }
  }

  component Sld: Item {
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
      width: 18
      height: 18
      radius: 9
      color: Theme.bright
    }
    Timer { id: thr; interval: 120; onTriggered: s.moved(s.value) }
    MouseArea {
      id: sma
      anchors.fill: parent
      function setFrom(mx) { s.value = Math.max(0, Math.min(1, mx / s.width)) }
      onPressed: (m) => { setFrom(m.x); thr.start() }
      onPositionChanged: (m) => { if (pressed) { setFrom(m.x); if (!thr.running) thr.start() } }
      onReleased: { thr.stop(); s.moved(s.value) }
    }
  }

  component Note: Text {
    id: n
    property real baseY: 0
    property int dur: 3000
    property int delay: 0
    text: ["♪", "♫", "♩", "♬"][Math.floor(Math.random() * 4)]
    color: Theme.dim
    font.family: pl.ff
    font.pixelSize: 22
    opacity: 0
    y: baseY
    SequentialAnimation {
      running: pl.shown && pl.playing
      loops: Animation.Infinite
      PauseAnimation { duration: n.delay }
      ParallelAnimation {
        NumberAnimation { target: n; property: "y"; from: n.baseY; to: n.baseY - 120; duration: n.dur; easing.type: Easing.OutQuad }
        SequentialAnimation {
          NumberAnimation { target: n; property: "opacity"; from: 0; to: 0.85; duration: n.dur * 0.25 }
          NumberAnimation { target: n; property: "opacity"; to: 0; duration: n.dur * 0.75 }
        }
      }
    }
  }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: pl.shown || card.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "player"
    WlrLayershell.keyboardFocus: pl.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: pl.shown = false
      Keys.onSpacePressed: pl.pc(["play-pause"])
      Keys.onLeftPressed: pl.pc(["position", "5-"])
      Keys.onRightPressed: pl.pc(["position", "5+"])
      Keys.onUpPressed: pl.setVol(pl.vol + 5)
      Keys.onDownPressed: pl.setVol(pl.vol - 5)

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        opacity: pl.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
      }
      MouseArea { anchors.fill: parent; onClicked: pl.shown = false }

      Rectangle {
        id: card
        width: 780
        height: 500
        anchors.horizontalCenter: parent.horizontalCenter
        y: pl.shown ? (parent.height - height) / 2 : (pl.fromTop ? -height - 40 : parent.height + 40)
        opacity: pl.shown ? 1 : 0
        radius: 28
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.88)
        border.color: Theme.line
        Behavior on y { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
        Behavior on opacity { NumberAnimation { duration: 260 } }
        MouseArea { anchors.fill: parent }

        Row {
          x: 32
          y: 32
          spacing: 28

          Rectangle {
            width: 200
            height: 200
            radius: 22
            color: Theme.surface
            border.color: Theme.line
            clip: true
            scale: 1 + pl.energy * 0.04
            Behavior on scale { NumberAnimation { duration: 90 } }
            Image {
              anchors.fill: parent
              source: pl.art
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              visible: pl.art !== ""
            }
            Txt { anchors.centerIn: parent; text: "♪"; font.pixelSize: 72; color: Theme.muted; visible: pl.art === "" }
          }

          Column {
            width: card.width - 64 - 200 - 28
            spacing: 8
            Txt {
              width: parent.width
              elide: Text.ElideRight
              text: pl.status === "none" ? "ничего не играет" : (pl.title || "—")
              font.pixelSize: 26
            }
            Txt { width: parent.width; elide: Text.ElideRight; text: pl.artist; color: Theme.dim; font.pixelSize: 16 }
            Txt { width: parent.width; elide: Text.ElideRight; text: pl.album; color: Theme.muted; font.pixelSize: 13 }
            Item { width: 1; height: 8 }
            Row {
              width: parent.width
              spacing: 10
              Txt { text: pl.fmt(pl.pos); width: 44; height: 28; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 12 }
              Sld { width: parent.width - 108; source: pl.len > 0 ? pl.pos / pl.len : 0; onMoved: v => pl.seekFrac(v) }
              Txt { text: pl.fmt(pl.len); width: 44; height: 28; verticalAlignment: Text.AlignVCenter; horizontalAlignment: Text.AlignRight; color: Theme.dim; font.pixelSize: 12 }
            }
            Flow {
              width: parent.width
              spacing: 10
              Pill { label: "shuffle"; active: pl.shuffle === "On"; onClicked: pl.pc(["shuffle", "Toggle"]) }
              Pill { label: "◀◀"; onClicked: pl.pc(["previous"]) }
              Pill { label: pl.playing ? "||" : "▶"; active: true; onClicked: pl.pc(["play-pause"]) }
              Pill { label: "▶▶"; onClicked: pl.pc(["next"]) }
              Pill { label: "loop: " + pl.loopMode.toLowerCase(); active: pl.loopMode !== "None"; onClicked: pl.pc(["loop", pl.nextLoop()]) }
            }
          }
        }

        Item {
          id: viz
          x: 32
          y: 260
          width: card.width - 64
          height: 140
          readonly property int n: 32
          readonly property real bw: (width - (n - 1) * 4) / n

          Repeater {
            model: viz.n
            Item {
              x: index * (viz.bw + 4)
              width: viz.bw
              height: viz.height
              readonly property real v: (pl.bars.length > index ? pl.bars[index] : 0) / 100
              Rectangle {
                width: parent.width
                height: Math.max(3, parent.v * 62)
                y: viz.height / 2 - height
                radius: width / 2
                color: Theme.fg
                Behavior on height { NumberAnimation { duration: 70 } }
              }
              Rectangle {
                width: parent.width
                height: Math.max(3, parent.v * 62)
                y: viz.height / 2 + 2
                radius: width / 2
                color: Theme.dim
                opacity: 0.55
                Behavior on height { NumberAnimation { duration: 70 } }
              }
            }
          }

          Note { x: viz.width * 0.08; baseY: 40; dur: 3400; delay: 0 }
          Note { x: viz.width * 0.24; baseY: 40; dur: 2900; delay: 700 }
          Note { x: viz.width * 0.42; baseY: 40; dur: 3600; delay: 300 }
          Note { x: viz.width * 0.58; baseY: 40; dur: 3100; delay: 1200 }
          Note { x: viz.width * 0.76; baseY: 40; dur: 3300; delay: 500 }
          Note { x: viz.width * 0.9;  baseY: 40; dur: 2800; delay: 1500 }
        }

        Txt {
          visible: !pl.cavaOk && !pl.demo
          x: 32
          y: 400
          text: "cava не запустился, визуализации нет (sudo dnf install cava)"
          color: Theme.muted
          font.pixelSize: 11
        }

        Flow {
          x: 32
          y: 424
          width: card.width - 64
          spacing: 10
          Txt { text: "vol " + pl.vol + "%"; width: 78; height: 34; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 13 }
          Sld { width: 190; height: 34; source: pl.vol / 100; onMoved: v => pl.setVol(Math.round(v * 100)) }
          Pill { label: pl.muted ? "unmute" : "mute"; active: pl.muted; onClicked: pl.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]) }
          Repeater {
            model: pl.sinks.slice(0, 3)
            Pill {
              label: pl.sh(modelData.desc)
              active: modelData.name === pl.defSink
              onClicked: { pl.run(["pactl", "set-default-sink", modelData.name]); pl.defSink = modelData.name; }
            }
          }
          Pill {
            visible: pl.players.length > 1
            label: "источник: " + (pl.sel || pl.players[0] || "")
            onClicked: pl.cycleSource()
          }
        }
      }
    }
  }
}
