import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: qk

  property bool shown: false
  property string page: "main"
  property string askSsid: ""
  property string msg: ""
  property string confirm: ""
  property bool wifiOn: false
  property string ssid: ""
  property bool btOn: false
  property string btDev: ""
  property int vol: 0
  property bool muted: false
  property int bri: -1
  property string profile: "none"
  property bool airplane: false
  property bool shaderOn: true
  property bool dndOn: false
  property int wsig: 0
  property string wrate: ""
  property real rxb: 0
  property real txb: 0
  property real rxSpeed: 0
  property real txSpeed: 0
  property real lastT: 0
  property bool nightOn: false
  property int nightTemp: 3500
  property var nets: []
  property var btList: []
  property var sinks: []
  property string defSink: ""
  property int volTarget: 0
  property int volSent: -1
  property int briTarget: 0
  property int briSent: -1
  property var queue: []
  function openNotifs() {
    shown = false;
    run(["sh", "-c", "sleep 0.4; swaync-client -op -sw || swaync-client -t -sw"]);
  }
  function toggleShader() {
    run(["bash", Quickshell.env("HOME") + "/.config/hypr/toggle-shader.sh"]);
  }
  function fmtSpeed(b) {
    if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s";
    if (b >= 1024) return Math.round(b / 1024) + " KB/s";
    return Math.round(b) + " B/s";
  }
  function setNight(on, temp) {
    nightTemp = temp;
    if (on) run(["sh", "-c", "command -v hyprsunset >/dev/null || { echo 'hyprsunset не установлен'; exit 1; }; pkill -x hyprsunset; sleep 0.2; setsid -f hyprsunset -t " + temp], "ночной режим " + temp + "K");
    else run(["sh", "-c", "pkill -x hyprsunset"]);
  }
  readonly property string ff: "JetBrains Mono"
  readonly property string scripts: Quickshell.env("HOME") + "/.config/quickshell/scripts"
  readonly property var profiles: ["power-saver", "balanced", "performance"]
  readonly property var profileNames: ({ "power-saver": "экономия", "balanced": "баланс", "performance": "мощность", "none": "нет данных" })

  onShownChanged: {
    if (!shown) { page = "main"; askSsid = ""; confirm = ""; msg = ""; }
  }
  onMsgChanged: { if (msg !== "") msgTimer.restart() }

  function refresh() { if (!statProc.running) statProc.running = true }
  function loadWifi() { if (!wifiProc.running) wifiProc.running = true }
  function loadBt() { if (!btProc.running) btProc.running = true }
  function loadAudio() { if (!audioProc.running) audioProc.running = true }
  function openPage(p) {
    page = p; askSsid = ""; msg = "";
    if (p === "wifi") loadWifi();
    else if (p === "bt") loadBt();
    else if (p === "audio") loadAudio();
  }
  function run(cmd, note) {
    queue.push({ cmd: cmd, note: note || "" });
    pump();
  }
  function pump() {
    if (act.running || queue.length === 0) return;
    const it = queue.shift();
    msg = it.note;
    act.command = it.cmd;
    act.running = true;
  }
  function setVol(v) { volTarget = Math.round(v * 100); if (!volAct.running) applyVol(); }
  function applyVol() {
    volSent = volTarget;
    volAct.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", volSent + "%"];
    volAct.running = true;
  }
  function setBri(v) { briTarget = Math.max(1, Math.round(v * 100)); if (!briAct.running) applyBri(); }
  function applyBri() {
    briSent = briTarget;
    briAct.command = ["brightnessctl", "set", briSent + "%"];
    briAct.running = true;
  }
  function connectWifi(name, pw) {
    run(["nmcli", "dev", "wifi", "connect", name].concat(pw ? ["password", pw] : []), "подключаю " + name + "…");
    askSsid = "";
  }
  function cycleProfile() {
    const i = profiles.indexOf(profile);
    run(["powerprofilesctl", "set", profiles[(i + 1) % profiles.length]]);
  }
  function confirmed(key, cmd) {
    if (confirm === key) { confirm = ""; run(cmd); }
    else { confirm = key; confirmTimer.restart(); }
  }

  IpcHandler {
    target: "quicksettings"
    function toggle(): void { qk.shown = !qk.shown }
    function show(): void { qk.shown = true }
    function hide(): void { qk.shown = false }
  }

  Timer {
    id: poll
    interval: 3000; running: qk.shown; repeat: true; triggeredOnStart: true
    onTriggered: qk.refresh()
  }
  Timer { id: confirmTimer; interval: 3000; onTriggered: qk.confirm = "" }
  Timer { id: msgTimer; interval: 6000; onTriggered: qk.msg = "" }

  Process {
    id: act
    stdout: StdioCollector { id: actOut }
    stderr: StdioCollector { id: actErr }
    onExited: {
      qk.msg = (actOut.text + actErr.text).trim().split("\n")[0];
      qk.refresh();
      if (qk.page === "wifi") qk.loadWifi();
      if (qk.page === "bt") qk.loadBt();
      if (qk.page === "audio") qk.loadAudio();
      qk.pump();
    }
  }
  Process {
    id: volAct
    onExited: { if (qk.volTarget !== qk.volSent) qk.applyVol(); else qk.refresh(); }
  }
  Process {
    id: briAct
    onExited: { if (qk.briTarget !== qk.briSent) qk.applyBri(); else qk.refresh(); }
  }

  Process {
    id: statProc
    command: ["bash", qk.scripts + "/status.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {};
        text.split("\n").forEach(l => {
          const i = l.indexOf("=");
          if (i > 0) m[l.slice(0, i)] = l.slice(i + 1);
        });
        qk.wifiOn = m.wifi === "on";
        qk.ssid = m.ssid || "";
        qk.btOn = m.bt === "on";
        qk.btDev = m.btdev || "";
        qk.vol = parseInt(m.vol) || 0;
        qk.muted = m.muted === "yes";
        const b = parseInt(m.bri);
        qk.bri = isNaN(b) ? -1 : b;
        qk.profile = m.profile || "none";
        qk.airplane = m.airplane === "yes";
        qk.shaderOn = m.shader !== "off";
        qk.dndOn = m.dnd === "true";
        qk.wsig = parseInt(m.wsig) || 0;
        qk.wrate = m.wrate || "";
        const now = Date.now();
        const rx = parseFloat(m.rxb);
        const tx = parseFloat(m.txb);
        if (!isNaN(rx) && !isNaN(tx) && qk.lastT > 0 && qk.rxb > 0 && now > qk.lastT) {
          const dt = (now - qk.lastT) / 1000;
          qk.rxSpeed = Math.max(0, (rx - qk.rxb) / dt);
          qk.txSpeed = Math.max(0, (tx - qk.txb) / dt);
        }
        if (!isNaN(rx)) { qk.rxb = rx; qk.txb = isNaN(tx) ? 0 : tx; qk.lastT = now; }
        qk.nightOn = m.night === "on";
      }
    }
  }
  Process {
    id: wifiProc
    command: ["bash", qk.scripts + "/wifi.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const saved = [];
        const nets = {};
        let sec = "";
        text.split("\n").forEach(l => {
          if (l === "##saved") { sec = "s"; return; }
          if (l === "##nets") { sec = "n"; return; }
          if (!l) return;
          if (sec === "s") { saved.push(l); return; }
          const p = l.split(":");
          if (p.length < 4) return;
          const inuse = p[0] === "*";
          const security = p[p.length - 1];
          const signal = parseInt(p[p.length - 2]) || 0;
          const name = p.slice(1, p.length - 2).join(":");
          if (!name) return;
          const cur = nets[name];
          if (!cur || signal > cur.signal || inuse) {
            nets[name] = { ssid: name, signal: signal, sec: security, inuse: inuse || (cur ? cur.inuse : false), saved: saved.indexOf(name) >= 0 };
          }
        });
        const arr = Object.keys(nets).map(k => nets[k]);
        arr.sort((a, b) => (b.inuse - a.inuse) || (b.signal - a.signal));
        qk.nets = arr;
      }
    }
  }
  Process {
    id: btProc
    command: ["bash", qk.scripts + "/bt.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const arr = [];
        text.split("\n").forEach(l => {
          const p = l.split("|");
          if (p.length >= 3 && p[0]) arr.push({ mac: p[0], connected: p[1] === "yes", name: p.slice(2).join("|") });
        });
        arr.sort((a, b) => (b.connected - a.connected));
        qk.btList = arr;
      }
    }
  }
  Process {
    id: audioProc
    command: ["bash", qk.scripts + "/audio.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const i = text.indexOf("##default");
        try {
          const j = JSON.parse(i >= 0 ? text.slice(0, i) : text);
          qk.sinks = j.map(s => ({ name: s.name, desc: s.description || s.name }));
        } catch (e) { qk.sinks = []; }
        qk.defSink = i >= 0 ? text.slice(i + 9).trim() : "";
      }
    }
  }

  component Txt: Text {
    color: Theme.fg
    font.family: qk.ff
  }

  component Pill: Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    signal clicked()
    width: lbl.implicitWidth + 24
    height: 32
    radius: 12
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

  component Tile: Rectangle {
    id: t
    property string title: ""
    property string sub: ""
    property bool active: false
    property bool arrow: false
    signal toggled()
    signal opened()
    width: 177
    height: 64
    radius: 16
    color: active ? Theme.fg : Theme.surface
    border.color: Theme.line
    Behavior on color { ColorAnimation { duration: 150 } }
    MouseArea {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: t.arrow ? parent.width - 40 : parent.width
      onClicked: t.toggled()
    }
    Column {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Txt { text: t.title; font.pixelSize: 14; color: t.active ? Theme.bg : Theme.fg }
      Txt { text: t.sub; width: 112; elide: Text.ElideRight; font.pixelSize: 11; color: t.active ? Theme.faint : Theme.dim }
    }
    Rectangle {
      visible: t.arrow
      anchors.right: parent.right
      anchors.rightMargin: 40
      anchors.verticalCenter: parent.verticalCenter
      width: 1
      height: 34
      color: t.active ? Theme.dim : Theme.line
    }
    MouseArea {
      visible: t.arrow
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: 40
      onClicked: t.opened()
      Txt { anchors.centerIn: parent; text: "›"; font.pixelSize: 22; color: t.active ? Theme.bg : Theme.fg }
    }
  }

  component Entry: Rectangle {
    id: en
    property string title: ""
    property string rtext: ""
    property bool active: false
    signal clicked()
    height: 44
    radius: 12
    color: active ? Theme.line : (ema.containsMouse ? Theme.surface2 : Theme.surface)
    border.color: active ? Theme.fg : Theme.line
    Behavior on color { ColorAnimation { duration: 150 } }
    Txt {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.right: rt.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: en.title
      elide: Text.ElideRight
      font.pixelSize: 13
    }
    Txt {
      id: rt
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      text: en.rtext
      color: Theme.dim
      font.pixelSize: 11
    }
    MouseArea { id: ema; anchors.fill: parent; hoverEnabled: true; onClicked: en.clicked() }
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

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: qk.shown || panel.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quick-settings"
    WlrLayershell.keyboardFocus: qk.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: {
        if (qk.askSsid !== "") qk.askSsid = "";
        else if (qk.page !== "main") qk.page = "main";
        else qk.shown = false;
      }
      MouseArea { anchors.fill: parent; onClicked: qk.shown = false }

      Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 54
        anchors.rightMargin: 12
        width: 400
        height: contentH + 36
        radius: 22
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.82)
        border.color: Theme.line
        opacity: qk.shown ? 1 : 0
        scale: qk.shown ? 1 : 0.96
        transformOrigin: Item.TopRight
        property real contentH: qk.page === "main" ? mainCol.implicitHeight
          : qk.page === "wifi" ? wifiCol.implicitHeight
          : qk.page === "bt" ? btCol.implicitHeight
          : qk.page === "audio" ? audioCol.implicitHeight
          : qk.page === "night" ? nightCol.implicitHeight
          : powerCol.implicitHeight
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        // ---------- главная ----------
        Column {
          id: mainCol
          visible: qk.page === "main"
          x: 18
          y: 18
          width: parent.width - 36
          spacing: 12

          Txt { text: "быстрые настройки"; color: Theme.dim; font.pixelSize: 13 }
          Grid {
            columns: 2
            spacing: 10
            Tile {
              title: "Wi-Fi"
              sub: qk.wifiOn ? (qk.ssid ? qk.ssid + " · " + qk.wsig + "%" : "включён") : "выключен"
              active: qk.wifiOn
              arrow: true
              onToggled: qk.run(["nmcli", "radio", "wifi", qk.wifiOn ? "off" : "on"])
              onOpened: qk.openPage("wifi")
            }
            Tile {
              title: "Bluetooth"
              sub: qk.btOn ? (qk.btDev || "включён") : "выключен"
              active: qk.btOn
              arrow: true
              onToggled: qk.run(["bluetoothctl", "power", qk.btOn ? "off" : "on"])
              onOpened: qk.openPage("bt")
            }
            Tile {
              title: "Звук"
              sub: qk.muted ? "без звука" : qk.vol + "%"
              active: !qk.muted
              arrow: true
              onToggled: qk.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
              onOpened: qk.openPage("audio")
            }
            Tile {
              title: "Питание"
              sub: qk.profileNames[qk.profile] || qk.profile
              active: qk.profile === "performance"
              arrow: true
              onToggled: qk.cycleProfile()
              onOpened: qk.openPage("power")
            }
            Tile {
              title: "Ночной режим"
              sub: qk.nightOn ? qk.nightTemp + "K" : "выключен"
              active: qk.nightOn
              arrow: true
              onToggled: qk.setNight(!qk.nightOn, qk.nightTemp)
              onOpened: qk.openPage("night")
            }
            Tile {
              title: "Режим полёта"
              sub: qk.airplane ? "включён" : "выключен"
              active: qk.airplane
              onToggled: qk.run(["rfkill", qk.airplane ? "unblock" : "block", "all"])
            }
            Tile {
              title: "Шейдер"
              sub: qk.shaderOn ? "включён" : "выключен"
              active: qk.shaderOn
              onToggled: qk.toggleShader()
            }
            Tile {
              title: "Не беспокоить"
              sub: qk.dndOn ? "включено" : "выключено"
              active: qk.dndOn
              onToggled: qk.run(["swaync-client", "-d", "-sw"])
            }
            Tile {
              title: "Уведомления"
              sub: "история и очистка"
              arrow: true
              onOpened: qk.openNotifs()
              onToggled: { qk.shown = false; qk.run(["sh", "-c", "sleep 0.4; swaync-client -op -sw || swaync-client -t -sw"]); }
            }
          }
          Row {
            width: parent.width
            spacing: 10
            Txt { text: "звук"; width: 64; height: 28; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 13 }
            Sld { width: parent.width - 74; source: qk.vol / 100; onMoved: v => qk.setVol(v) }
          }
          Row {
            visible: qk.bri >= 0
            width: parent.width
            spacing: 10
            Txt { text: "яркость"; width: 64; height: 28; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 13 }
            Sld { width: parent.width - 74; source: qk.bri / 100; onMoved: v => qk.setBri(v) }
          }
          Txt { visible: qk.msg !== ""; text: qk.msg; width: parent.width; wrapMode: Text.Wrap; color: Theme.dim; font.pixelSize: 11 }
        }

        // ---------- Wi-Fi ----------
        Column {
          id: wifiCol
          visible: qk.page === "wifi"
          x: 18
          y: 18
          width: parent.width - 36
          spacing: 10

          Row {
            spacing: 8
            Pill { label: "‹ назад"; onClicked: qk.page = "main" }
            Pill { label: qk.wifiOn ? "выключить" : "включить"; active: qk.wifiOn; onClicked: qk.run(["nmcli", "radio", "wifi", qk.wifiOn ? "off" : "on"]) }
            Pill { label: "обновить"; onClicked: qk.loadWifi() }
          }
          Txt { text: !qk.wifiOn ? "Wi-Fi выключен" : (qk.nets.length === 0 ? "сетей не найдено" : "доступные сети"); color: Theme.dim; font.pixelSize: 12 }
          Txt { visible: qk.ssid !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.fg; font.pixelSize: 12; text: "сигнал " + qk.wsig + "% · канал " + (qk.wrate || "—") + " · ↓ " + qk.fmtSpeed(qk.rxSpeed) + "  ↑ " + qk.fmtSpeed(qk.txSpeed) }
          ListView {
            id: wifiList
            width: parent.width
            height: Math.min(280, contentHeight)
            clip: true
            spacing: 6
            model: qk.nets
            delegate: Entry {
              width: wifiList.width
              title: modelData.ssid
              rtext: modelData.inuse ? "подключено" : (modelData.signal + "%" + (modelData.sec ? " · " + modelData.sec : ""))
              active: modelData.inuse
              onClicked: {
                if (modelData.inuse) qk.run(["nmcli", "connection", "down", "id", modelData.ssid], "отключаю…");
                else if (modelData.saved || modelData.sec === "") qk.connectWifi(modelData.ssid, "");
                else qk.askSsid = modelData.ssid;
              }
            }
          }
          Rectangle {
            visible: qk.askSsid !== ""
            width: parent.width
            height: 44
            radius: 12
            color: Theme.surface
            border.color: Theme.fg
            TextInput {
              id: pwIn
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.right: goBtn.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              echoMode: TextInput.Password
              color: Theme.fg
              font.family: qk.ff
              font.pixelSize: 13
              clip: true
              onAccepted: qk.connectWifi(qk.askSsid, text)
            }
            Txt {
              anchors.fill: pwIn
              verticalAlignment: Text.AlignVCenter
              text: "пароль для " + qk.askSsid
              color: Theme.muted
              font.pixelSize: 12
              visible: pwIn.text === ""
            }
            Pill {
              id: goBtn
              anchors.right: parent.right
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              label: "ок"
              onClicked: qk.connectWifi(qk.askSsid, pwIn.text)
            }
            Connections {
              target: qk
              function onAskSsidChanged() {
                if (qk.askSsid !== "") { pwIn.text = ""; pwIn.forceActiveFocus(); }
              }
            }
          }
          Txt { visible: qk.msg !== ""; text: qk.msg; width: parent.width; wrapMode: Text.Wrap; color: Theme.dim; font.pixelSize: 11 }
        }

        // ---------- Bluetooth ----------
        Column {
          id: btCol
          visible: qk.page === "bt"
          x: 18
          y: 18
          width: parent.width - 36
          spacing: 10

          Row {
            spacing: 8
            Pill { label: "‹ назад"; onClicked: qk.page = "main" }
            Pill { label: qk.btOn ? "выключить" : "включить"; active: qk.btOn; onClicked: qk.run(["bluetoothctl", "power", qk.btOn ? "off" : "on"]) }
            Pill { label: "поиск"; onClicked: qk.run(["bluetoothctl", "--timeout", "8", "scan", "on"], "ищу устройства…") }
          }
          Txt { text: !qk.btOn ? "Bluetooth выключен" : (qk.btList.length === 0 ? "устройств нет, нажми «поиск»" : "устройства"); color: Theme.dim; font.pixelSize: 12 }
          ListView {
            id: btList
            width: parent.width
            height: Math.min(280, contentHeight)
            clip: true
            spacing: 6
            model: qk.btList
            delegate: Entry {
              width: btList.width
              title: modelData.name
              rtext: modelData.connected ? "подключено" : "подключить"
              active: modelData.connected
              onClicked: {
                if (modelData.connected) qk.run(["bluetoothctl", "disconnect", modelData.mac], "отключаю…");
                else qk.run(["sh", "-c", "bluetoothctl pair \"$1\"; bluetoothctl trust \"$1\"; bluetoothctl connect \"$1\"", "sh", modelData.mac], "подключаю " + modelData.name + "…");
              }
            }
          }
          Txt { visible: qk.msg !== ""; text: qk.msg; width: parent.width; wrapMode: Text.Wrap; color: Theme.dim; font.pixelSize: 11 }
        }

        // ---------- звук ----------
        Column {
          id: audioCol
          visible: qk.page === "audio"
          x: 18
          y: 18
          width: parent.width - 36
          spacing: 10

          Row {
            spacing: 8
            Pill { label: "‹ назад"; onClicked: qk.page = "main" }
            Pill { label: qk.muted ? "включить звук" : "выключить звук"; active: !qk.muted; onClicked: qk.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]) }
          }
          Txt { text: qk.sinks.length === 0 ? "устройств вывода нет" : "устройство вывода"; color: Theme.dim; font.pixelSize: 12 }
          ListView {
            id: sinkList
            width: parent.width
            height: Math.min(220, contentHeight)
            clip: true
            spacing: 6
            model: qk.sinks
            delegate: Entry {
              width: sinkList.width
              title: modelData.desc
              rtext: modelData.name === qk.defSink ? "выбрано" : ""
              active: modelData.name === qk.defSink
              onClicked: qk.run(["pactl", "set-default-sink", modelData.name])
            }
          }
          Row {
            width: parent.width
            spacing: 10
            Txt { text: "громкость"; width: 86; height: 28; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 13 }
            Sld { width: parent.width - 96; source: qk.vol / 100; onMoved: v => qk.setVol(v) }
          }
          Txt { visible: qk.msg !== ""; text: qk.msg; width: parent.width; wrapMode: Text.Wrap; color: Theme.dim; font.pixelSize: 11 }
        }

        // ---------- питание ----------

        Column {
          id: nightCol
          visible: qk.page === "night"
          x: 18
          y: 18
          width: parent.width - 36
          spacing: 12

          Row {
            spacing: 8
            Pill { label: "‹ назад"; onClicked: qk.page = "main" }
            Pill { label: qk.nightOn ? "выключить" : "включить"; active: qk.nightOn; onClicked: qk.setNight(!qk.nightOn, qk.nightTemp) }
          }
          Txt { text: "температура: " + qk.nightTemp + "K (чем ниже, тем теплее)"; color: Theme.dim; font.pixelSize: 12 }
          Row {
            spacing: 8
            Repeater {
              model: [4500, 3800, 3200, 2600]
              Pill { label: modelData + "K"; active: qk.nightOn && qk.nightTemp === modelData; onClicked: qk.setNight(true, modelData) }
            }
          }
          Txt { visible: qk.msg !== ""; text: qk.msg; width: parent.width; wrapMode: Text.Wrap; color: Theme.dim; font.pixelSize: 11 }
        }
        Column {
          id: powerCol
          visible: qk.page === "power"
          x: 18
          y: 18
          width: parent.width - 36
          spacing: 12

          Row {
            spacing: 8
            Pill { label: "‹ назад"; onClicked: qk.page = "main" }
            Pill { label: qk.airplane ? "режим полёта: вкл" : "режим полёта: выкл"; active: qk.airplane; onClicked: qk.run(["rfkill", qk.airplane ? "unblock" : "block", "all"]) }
          }
          Txt { text: "профиль производительности"; color: Theme.dim; font.pixelSize: 12 }
          Row {
            spacing: 8
            Repeater {
              model: qk.profiles
              Pill {
                label: qk.profileNames[modelData]
                active: qk.profile === modelData
                onClicked: qk.run(["powerprofilesctl", "set", modelData])
              }
            }
          }
          Txt { text: "сеанс"; color: Theme.dim; font.pixelSize: 12 }
          Flow {
            width: parent.width
            spacing: 8
            Pill { label: "заблокировать"; onClicked: { qk.shown = false; qk.run(["sh", "-c", "setsid -f hyprlock"]); } }
            Pill { label: "сон"; onClicked: { qk.shown = false; qk.run(["systemctl", "suspend"]); } }
            Pill { label: "выйти"; onClicked: qk.run(["hyprctl", "dispatch", "hl.dsp.exit()"]) }
            Pill { label: qk.confirm === "reboot" ? "точно?" : "перезагрузка"; active: qk.confirm === "reboot"; onClicked: qk.confirmed("reboot", ["systemctl", "reboot"]) }
            Pill { label: qk.confirm === "off" ? "точно?" : "выключить"; active: qk.confirm === "off"; onClicked: qk.confirmed("off", ["systemctl", "poweroff"]) }
          }
          Txt { visible: qk.msg !== ""; text: qk.msg; width: parent.width; wrapMode: Text.Wrap; color: Theme.dim; font.pixelSize: 11 }
        }
      }
    }
  }
}
