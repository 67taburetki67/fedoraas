import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: root

  property bool shown: false
  property bool editing: false
  property bool picking: false
  property int cpu: 0
  property int mem: 0
  property int temp: 0
  property var cpuHist: []
  property var memHist: []
  property string disk: "—"
  property string upt: "—"
  property string net: "—"
  property string wTemp: "—"
  property string wCond: ""
  property var wDays: []
  property string pStatus: "none"
  property string pArtist: ""
  property string pTitle: ""
  property string pArt: ""
  property real pLen: 0
  property real pPos: 0
  property string pmMode: "work"
  property int pmLeft: 1500
  property bool pmRunning: false
  property var todos: []
  property var events: []
  property var evKeys: ({})
  property var stickerIds: []
  property string stickerMsg: ""
  property var themeList: ["gray", "blue", "green"]
  property string curTheme: ""
  property string themeMsg: ""
  property string pendingTheme: ""
  readonly property date now: clock.date
  readonly property int notesCount: notesView.boards.length
  readonly property string notesPreview: notesView.latestPreview
  readonly property string home: Quickshell.env("HOME")
  readonly property string scripts: home + "/.config/quickshell/scripts"
  readonly property var months: ["Январь","Февраль","Март","Апрель","Май","Июнь","Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"]
  readonly property var monthsGen: ["января","февраля","марта","апреля","мая","июня","июля","августа","сентября","октября","ноября","декабря"]
  readonly property var weekdays: ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
  readonly property var order: ["clock","calendar","weather","gauges","history","player","pomodoro","todo","notes","apps","info","themes"]
  readonly property var names: ({ clock: "часы", calendar: "календарь", weather: "погода", gauges: "нагрузка", history: "график", player: "плеер", pomodoro: "помодоро", todo: "задачи", notes: "заметки", apps: "приложения", info: "система", themes: "темы" })
  readonly property var pmDur: ({ work: 1500, short: 300, long: 900 })
  readonly property var pmNames: ({ work: "работа", short: "перерыв", long: "длинный перерыв" })
  readonly property var upcoming: {
    const today = Qt.formatDate(clock.date, "yyyy-MM-dd");
    return events.filter(e => e.date >= today).slice(0, 3);
  }

  readonly property var defaults: ({
    version: 2,
    settings: { city: "", dim: 0.55, hideWindows: true },
    widgets: {
      clock:    { on: true, x: 0.35, y: 0.20, w: 0.30, h: 0.22, a: 1.0, bg: 0.0 },
      calendar: { on: true, x: 0.03, y: 0.06, w: 0.15, h: 0.36, a: 1.0, bg: 0.6 },
      weather:  { on: true, x: 0.80, y: 0.05, w: 0.17, h: 0.18, a: 1.0, bg: 0.6 },
      gauges:   { on: true, x: 0.80, y: 0.25, w: 0.17, h: 0.17, a: 1.0, bg: 0.6 },
      history:  { on: true, x: 0.77, y: 0.45, w: 0.20, h: 0.18, a: 1.0, bg: 0.6 },
      player:   { on: true, x: 0.03, y: 0.44, w: 0.18, h: 0.16, a: 1.0, bg: 0.6 },
      pomodoro: { on: true, x: 0.35, y: 0.46, w: 0.14, h: 0.17, a: 1.0, bg: 0.6 },
      todo:     { on: true, x: 0.03, y: 0.62, w: 0.16, h: 0.28, a: 1.0, bg: 0.6 },
      notes:    { on: true, x: 0.80, y: 0.66, w: 0.17, h: 0.24, a: 1.0, bg: 0.6 },
      apps:     { on: true, x: 0.38, y: 0.64, w: 0.24, h: 0.13, a: 1.0, bg: 0.6 },
      info:     { on: true, x: 0.42, y: 0.82, w: 0.16, h: 0.13, a: 1.0, bg: 0.6 },
      themes:   { on: true, x: 0.51, y: 0.43, w: 0.20, h: 0.21, a: 1.0, bg: 0.6 }
    },
    stickers: ({}),
    apps: [ { name: "Firefox", cmd: "firefox" }, { name: "Терминал", cmd: "foot" } ]
  })
  property var cfg: JSON.parse(JSON.stringify(defaults))

  function applyConfig(txt) {
    try {
      const c = JSON.parse(txt);
      const base = JSON.parse(JSON.stringify(defaults));
      if (c.settings) Object.assign(base.settings, c.settings);
      if (c.version === 2 && c.widgets) {
        for (const k in c.widgets) if (base.widgets[k]) base.widgets[k] = Object.assign({}, base.widgets[k], c.widgets[k]);
      }
      if (c.version === 2 && c.stickers) base.stickers = c.stickers;
      if (c.apps) base.apps = c.apps;
      cfg = base;
      stickerIds = Object.keys(base.stickers);
    } catch (e) { console.log("widgets.json: " + e); }
  }
  function saveConfig() { cfgFile.setText(JSON.stringify(cfg, null, 2)); }
  function setGeom(kind, id, prop, val) {
    const c = JSON.parse(JSON.stringify(cfg));
    const t = kind === "s" ? c.stickers[id] : c.widgets[id];
    if (!t) return;
    t[prop] = val;
    cfg = c;
  }
  function setWidgetOn(key, on) {
    const c = JSON.parse(JSON.stringify(cfg));
    c.widgets[key].on = on;
    cfg = c;
    saveConfig();
  }
  function setSetting(prop, val) {
    const c = JSON.parse(JSON.stringify(cfg));
    c.settings[prop] = val;
    cfg = c;
    saveConfig();
  }
  function resetLayout() {
    const c = JSON.parse(JSON.stringify(cfg));
    c.widgets = JSON.parse(JSON.stringify(defaults.widgets));
    cfg = c;
    saveConfig();
  }

  function addSticker(path) {
    const ext = path.split(".").pop().toLowerCase();
    let type = "";
    if (ext === "gif") type = "gif";
    else if (["png", "jpg", "jpeg", "webp", "bmp"].indexOf(ext) >= 0) type = "image";
    else { stickerMsg = "нужна картинка или GIF"; return; }
    const c = JSON.parse(JSON.stringify(cfg));
    const id = "s" + Date.now().toString(36) + Math.floor(Math.random() * 1000).toString(36);
    const n = stickerIds.length % 5;
    c.stickers[id] = { path: path, type: type, x: 0.42 + n * 0.02, y: 0.30 + n * 0.02, w: 0.16, h: 0.22, a: 1.0 };
    cfg = c;
    stickerIds = stickerIds.concat([id]);
    stickerMsg = "";
    saveConfig();
  }
  function delSticker(id) {
    const c = JSON.parse(JSON.stringify(cfg));
    delete c.stickers[id];
    cfg = c;
    stickerIds = stickerIds.filter(x => x !== id);
    saveConfig();
  }
  function stickerFrom(kind) {
    if (stickerProc.running) return;
    stickerMsg = "";
    picking = (kind === "pick");
    stickerProc.command = ["bash", scripts + "/notes-media.sh", kind];
    stickerProc.running = true;
  }

  function fmt(s) {
    s = Math.max(0, Math.floor(s));
    const m = Math.floor(s / 60);
    const r = s % 60;
    return m + ":" + (r < 10 ? "0" : "") + r;
  }
  function refreshWeather() { if (!wProc.running) wProc.running = true }
  function refreshPlayer() { if (!plProc.running) plProc.running = true }
  function player(args) {
    pAct.command = ["playerctl"].concat(args);
    pAct.running = true;
    Qt.callLater(refreshPlayer);
  }
  function seekFrac(f) {
    if (pLen > 0) { pPos = f * pLen; player(["position", String(Math.round(pPos))]); }
  }
  function launch(cmd) {
    shown = false;
    launchAct.command = ["sh", "-c", "sleep 0.5; setsid -f " + cmd + " >/dev/null 2>&1"];
    launchAct.running = true;
  }
  function openNotes() {
    editing = false;
    shown = false;
    notesView.open = true;
  }
  function runTheme(args) {
    themeAct.command = ["bash", home + "/.local/bin/theme"].concat(args.split(" "));
    themeAct.running = true;
  }
  function setTheme(n) { if (themeAct.running) pendingTheme = n; else runTheme(n); }
  function wall(mode) { if (themeAct.running) pendingTheme = "wall " + mode; else runTheme("wall " + mode); }

  function saveTodos() { todoFile.setText(JSON.stringify(todos)); }
  function addTodo(t) {
    t = t.trim();
    if (!t) return;
    const a = todos.slice();
    a.push({ text: t, done: false });
    todos = a;
    saveTodos();
  }
  function toggleTodo(i) {
    const a = todos.slice();
    a[i] = { text: a[i].text, done: !a[i].done };
    todos = a;
    saveTodos();
  }
  function delTodo(i) { const a = todos.slice(); a.splice(i, 1); todos = a; saveTodos(); }
  function clearDone() { todos = todos.filter(t => !t.done); saveTodos(); }

  function parseEvents(txt) {
    const list = [];
    const keys = {};
    txt.split("\n").forEach(l => {
      const m = l.trim().match(/^(\d{4}-\d{2}-\d{2})\s+(.+)$/);
      if (m) { list.push({ date: m[1], text: m[2] }); keys[m[1]] = true; }
    });
    list.sort((a, b) => a.date < b.date ? -1 : (a.date > b.date ? 1 : 0));
    events = list;
    evKeys = keys;
  }

  function pmSet(mode) { pmMode = mode; pmLeft = pmDur[mode]; pmRunning = false; }
  function pmNext() { pmSet(pmMode === "work" ? "short" : (pmMode === "short" ? "long" : "work")); }
  function pmToggle() { pmRunning = !pmRunning; }
  function pmTick() {
    if (pmLeft > 0) { pmLeft = pmLeft - 1; return; }
    const done = pmNames[pmMode];
    pmRunning = false;
    notifyAct.command = ["sh", "-c", "command -v notify-send >/dev/null && notify-send 'Помодоро' 'Закончилось: " + done + "' || true"];
    notifyAct.running = true;
    pmNext();
  }

  onShownChanged: {
    if (!shown) editing = false;
    (shown ? subOn : subOff).running = true;
    if (!cfg.settings.hideWindows) return;
    if (shown) wsHide.running = true;
    else wsRestore.running = true;
  }

  FileView {
    id: cfgFile
    path: root.home + "/.config/quickshell/widgets.json"
    onLoaded: root.applyConfig(cfgFile.text())
  }
  FileView {
    id: todoFile
    path: root.home + "/.config/quickshell/todo.json"
    onLoaded: { try { root.todos = JSON.parse(todoFile.text()); } catch (e) { root.todos = []; } }
  }
  FileView {
    id: evFile
    path: root.home + "/.config/quickshell/events.txt"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.parseEvents(evFile.text())
  }
  FileView {
    id: themeCur
    path: root.home + "/.config/themes/current"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.curTheme = themeCur.text().trim()
  }

  SystemClock {
    id: clock
    precision: root.shown ? SystemClock.Seconds : SystemClock.Minutes
  }

  QuickSettings { }
  Launcher { }
  OSD { }
  Player { }
  Cheatsheet { }
  NotesView { id: notesView }

  IpcHandler {
    target: "widgets"
    function toggle(): void { root.shown = !root.shown }
    function show(): void { root.shown = true }
    function hide(): void { root.shown = false }
  }

  Process { id: pAct }
  Process { id: launchAct }
  Process { id: notifyAct }
  Process {
    id: roundProc
    stdout: StdioCollector {
      onStreamFinished: {
        const out = text.trim().split("\n").filter(x => x);
        out.forEach(l => { if (l.indexOf("NOTE:") === 0) root.stickerMsg = l.slice(5); });
        const last = out.length ? out[out.length - 1] : "";
        if (last && last.indexOf("NOTE:") !== 0) root.addSticker(last);
      }
    }
  }
  Process { id: wsHide; command: ["bash", root.scripts + "/ws.sh", "hide"] }
  Process { id: wsRestore; command: ["bash", root.scripts + "/ws.sh", "restore"] }
  Process { id: subOn; command: ["hyprctl", "dispatch", 'hl.dsp.submap("widgets")'] }
  Process { id: subOff; command: ["hyprctl", "dispatch", 'hl.dsp.submap("reset")'] }

  Process {
    id: stickerProc
    stdout: StdioCollector {
      onStreamFinished: {
        const out = text.trim().split("\n").filter(x => x);
        const last = out.length ? out[out.length - 1] : "";
        if (last.indexOf("ERR:") === 0) root.stickerMsg = last.slice(4);
        else if (last) { root.stickerMsg = "скругляю…"; roundProc.command = ["bash", root.scripts + "/round-image.sh", last]; roundProc.running = true; }
      }
    }
    onExited: root.picking = false
  }
  Process {
    id: themeAct
    stderr: StdioCollector { id: themeErr }
    onExited: {
      root.themeMsg = themeErr.text.trim().split("\n")[0];
      themeCur.reload();
      if (root.pendingTheme !== "") { const p = root.pendingTheme; root.pendingTheme = ""; root.runTheme(p); }
    }
  }
  Process {
    id: themeListProc
    command: ["bash", root.home + "/.local/bin/theme", "list"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const l = text.trim().split("\n").filter(x => x);
        if (l.length) root.themeList = l;
      }
    }
  }
  Process {
    id: sysProc
    command: ["bash", root.scripts + "/sys.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const p = text.trim().split(" ");
        if (p.length >= 2) {
          root.cpu = parseInt(p[0]) || 0;
          root.mem = parseInt(p[1]) || 0;
          root.temp = p.length >= 3 ? (parseInt(p[2]) || 0) : 0;
          const c = root.cpuHist.concat([root.cpu]);
          root.cpuHist = c.length > 60 ? c.slice(c.length - 60) : c;
          const m = root.memHist.concat([root.mem]);
          root.memHist = m.length > 60 ? m.slice(m.length - 60) : m;
        }
      }
    }
  }
  Process {
    id: infoProc
    command: ["bash", root.scripts + "/info.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const p = text.trim().split("|");
        if (p.length >= 3) { root.disk = p[0]; root.upt = p[1]; root.net = p[2]; }
      }
    }
  }
  Process {
    id: plProc
    command: ["bash", root.scripts + "/player.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {};
        text.split("\n").forEach(l => {
          const i = l.indexOf("=");
          if (i > 0) m[l.slice(0, i)] = l.slice(i + 1);
        });
        root.pStatus = m.status || "none";
        root.pArtist = m.artist || "";
        root.pTitle = m.title || "";
        root.pArt = m.art || "";
        root.pLen = (parseFloat(m.len) || 0) / 1000000;
        root.pPos = parseFloat(m.pos) || 0;
      }
    }
  }
  Process {
    id: wProc
    command: ["curl", "-s", "--max-time", "8", "wttr.in/" + encodeURIComponent(root.cfg.settings.city) + "?format=j1"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text);
          const cc = j.current_condition[0];
          root.wTemp = cc.temp_C + "°C";
          root.wCond = cc.weatherDesc && cc.weatherDesc[0] ? cc.weatherDesc[0].value : "";
          root.wDays = j.weather.slice(0, 3).map(d => ({
            day: root.weekdays[(new Date(d.date + "T12:00:00").getDay() + 6) % 7],
            max: d.maxtempC,
            min: d.mintempC,
            desc: d.hourly && d.hourly[4] && d.hourly[4].weatherDesc ? d.hourly[4].weatherDesc[0].value : ""
          }));
        } catch (e) { }
      }
    }
  }

  Timer { interval: 2000; running: root.shown; repeat: true; triggeredOnStart: true; onTriggered: { if (!sysProc.running) sysProc.running = true; } }
  Timer { interval: 5000; running: root.shown; repeat: true; triggeredOnStart: true; onTriggered: { if (!infoProc.running) infoProc.running = true; } }
  Timer { interval: 1500; running: root.shown; repeat: true; triggeredOnStart: true; onTriggered: root.refreshPlayer() }
  Timer { interval: 250; running: root.shown && root.pStatus === "Playing"; repeat: true; onTriggered: root.pPos = root.pLen > 0 ? Math.min(root.pLen, root.pPos + 0.25) : root.pPos + 0.25 }
  Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshWeather() }
  Timer { interval: 1000; running: root.pmRunning; repeat: true; onTriggered: root.pmTick() }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: (root.shown || content.opacity > 0.01) && !root.picking
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desktop-widgets"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      id: content
      anchors.fill: parent
      focus: true
      opacity: root.shown ? 1 : 0
      scale: root.shown ? 1 : 0.97
      Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Keys.onEscapePressed: { if (root.editing) root.editing = false; else root.shown = false; }

      Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, root.cfg.settings.dim) }
      MouseArea { anchors.fill: parent; onClicked: { if (!root.editing) root.shown = false } }

      PawLayer { anchors.fill: parent; active: root.shown }
      // наклейки: фото и GIF
      Repeater {
        model: root.stickerIds
        WFrame {
          id: sf
          sh: root
          kind: "s"
          gid: modelData
          g: root.cfg.stickers[modelData]
          card: false
          deletable: true
          idx: 12 + index
          WSticker { anchors.fill: parent; src: sf.g ? sf.g.path : ""; gif: !!sf.g && sf.g.type === "gif"; active: root.shown }
        }
      }

      WFrame { sh: root; gid: "clock"; g: root.cfg.widgets.clock; card: false; idx: 0
        WClock { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "calendar"; g: root.cfg.widgets.calendar; idx: 1
        WCalendar { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "weather"; g: root.cfg.widgets.weather; idx: 2
        WWeather { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "gauges"; g: root.cfg.widgets.gauges; idx: 3
        WGauges { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "history"; g: root.cfg.widgets.history; idx: 4
        WHistory { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "player"; g: root.cfg.widgets.player; idx: 5
        WPlayer { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "pomodoro"; g: root.cfg.widgets.pomodoro; idx: 6
        WPomodoro { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "todo"; g: root.cfg.widgets.todo; idx: 7
        WTodo { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "notes"; g: root.cfg.widgets.notes; idx: 8
        WNotes { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "apps"; g: root.cfg.widgets.apps; idx: 9
        WApps { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "info"; g: root.cfg.widgets.info; idx: 10
        WInfo { anchors.fill: parent; sh: root } }
      WFrame { sh: root; gid: "themes"; g: root.cfg.widgets.themes; idx: 11
        WThemes { anchors.fill: parent; sh: root } }

      // кнопка настройки
      WPill {
        z: 20
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        label: root.editing ? "готово" : "настроить"
        active: root.editing
        onClicked: root.editing = !root.editing
      }

      // панель настройки
      WCard {
        z: 20
        visible: root.editing
        bgA: 0.93
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: Math.min(parent.width - 60, 980)
        height: ed.implicitHeight + 36
        Column {
          id: ed
          x: 18
          y: 18
          width: parent.width - 36
          spacing: 12
          WTxt {
            text: "карточку тащи мышью, края и угол меняют ширину и высоту, внизу ползунки: вид (всей карточки) и фон (только заднего фона)"
            color: Theme.dim
            font.pixelSize: 12
            width: parent.width
            wrapMode: Text.Wrap
          }
          Flow {
            width: parent.width
            spacing: 8
            Repeater {
              model: root.order
              WPill {
                label: root.names[modelData]
                active: root.cfg.widgets[modelData].on
                onClicked: root.setWidgetOn(modelData, !root.cfg.widgets[modelData].on)
              }
            }
          }
          Flow {
            width: parent.width
            spacing: 8
            WTxt { text: "наклейки"; height: 32; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 13 }
            WPill { label: "+ фото из буфера"; onClicked: root.stickerFrom("paste") }
            WPill { label: "+ фото/GIF файлом"; onClicked: root.stickerFrom("pick") }
            WTxt { text: root.stickerMsg !== "" ? root.stickerMsg : (root.stickerIds.length + " шт."); height: 32; verticalAlignment: Text.AlignVCenter; color: Theme.muted; font.pixelSize: 12 }
          }
          Flow {
            width: parent.width
            spacing: 8
            WTxt { text: "город"; height: 32; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 13 }
            Rectangle {
              width: 180
              height: 32
              radius: 12
              color: Theme.surface
              border.color: Theme.line
              TextInput {
                id: cityIn
                anchors.fill: parent
                anchors.margins: 8
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                text: root.cfg.settings.city
                onAccepted: { root.setSetting("city", text); root.refreshWeather(); focus = false; }
              }
              WTxt {
                anchors.fill: parent
                anchors.margins: 8
                verticalAlignment: Text.AlignVCenter
                text: "авто (Enter)"
                color: Theme.muted
                font.pixelSize: 13
                visible: cityIn.text === "" && !cityIn.activeFocus
              }
            }
            WPill {
              label: "прятать окна: " + (root.cfg.settings.hideWindows ? "да" : "нет")
              active: root.cfg.settings.hideWindows
              onClicked: root.setSetting("hideWindows", !root.cfg.settings.hideWindows)
            }
            WTxt { text: "затемнение"; height: 32; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 13 }
            WPill { label: "−"; onClicked: root.setSetting("dim", Math.max(0, Math.round((root.cfg.settings.dim - 0.1) * 10) / 10)) }
            WTxt { text: Math.round(root.cfg.settings.dim * 100) + "%"; height: 32; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
            WPill { label: "+"; onClicked: root.setSetting("dim", Math.min(1, Math.round((root.cfg.settings.dim + 0.1) * 10) / 10)) }
          }
          Flow {
            width: parent.width
            spacing: 8
            WPill { label: "сбросить раскладку"; onClicked: root.resetLayout() }
            WPill { label: "перечитать файл"; onClicked: cfgFile.reload() }
          }
        }
      }
    }
  }
}
