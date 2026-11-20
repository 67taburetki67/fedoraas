import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: nt

  property bool open: false
  property bool picking: false
  property bool recording: false
  property bool loaded: false
  property bool haveStore: false
  property bool storeDone: false
  property bool oldDone: false
  property bool legacyDone: false
  readonly property int schemaVersion: 2
  property bool syncing: false
  property var boards: []
  property int rev: 0
  property string selId: ""
  property var items: []
  property string query: ""
  property string msg: ""
  property string playing: ""
  property string pendingPlay: ""
  property string previewPath: ""
  property string confirmDel: ""
  property int zTop: 1

  readonly property string ff: "JetBrains Mono"
  readonly property string home: Quickshell.env("HOME")
  readonly property string dir: home + "/.local/share/quickshell-notes"
  readonly property string media: home + "/.config/quickshell/scripts/notes-media.sh"
  readonly property var notes: boards

  readonly property var sorted: {
    rev;
    const q = query.trim().toLowerCase();
    const a = boards.filter(b => q === "" || ((b.title || "") + " " + b.items.map(i => i.text || "").join(" ")).toLowerCase().indexOf(q) >= 0);
    a.sort((x, y) => ((y.pinned ? 1 : 0) - (x.pinned ? 1 : 0)) || (y.updated - x.updated));
    return a;
  }
  readonly property string latestPreview: {
    rev;
    if (boards.length === 0) return "пока пусто";
    let best = boards[0];
    for (let i = 0; i < boards.length; i++) if (boards[i].updated > best.updated) best = boards[i];
    const t = ((best.title ? best.title + "\n" : "") + best.items.filter(i => i.type === "text").map(i => i.text).join("\n")).trim();
    if (!t) return best.items.length ? "(доска: " + best.items.length + " объектов)" : "пустая доска";
    return t.length > 240 ? t.slice(0, 240) + "…" : t;
  }

  function uid() { return Date.now().toString(36) + Math.floor(Math.random() * 100000).toString(36); }
  function cur() {
    for (let i = 0; i < boards.length; i++) if (boards[i].id === selId) return boards[i];
    return null;
  }
  function save() { saveTimer.restart(); }
  function flush() {
    // пока данные не прочитаны, писать нельзя: иначе пустая доска затрёт boards.json
    if (!loaded) return;
    store.setText(JSON.stringify({ version: schemaVersion, boards: boards }));
  }

  // ---- проверка структуры данных ----
  function finite(v, d) { return (typeof v === "number" && isFinite(v)) ? v : d; }
  function cleanItem(i) {
    if (!i || typeof i !== "object") return null;
    if (["text", "image", "gif", "audio", "file"].indexOf(i.type) < 0) return null;
    const o = { id: (typeof i.id === "string" && i.id) ? i.id : uid(), type: i.type,
                x: finite(i.x, 40), y: finite(i.y, 40), w: Math.max(90, finite(i.w, 280)), h: Math.max(70, finite(i.h, 200)), z: finite(i.z, 1) };
    if (i.type === "text") o.text = (typeof i.text === "string") ? i.text : "";
    else {
      o.path = (typeof i.path === "string") ? i.path : "";
      o.name = (typeof i.name === "string") ? i.name : o.path.split("/").pop();
    }
    return o;
  }
  function cleanBoard(b) {
    if (!b || typeof b !== "object") return null;
    const its = Array.isArray(b.items) ? b.items.map(cleanItem).filter(x => x !== null) : [];
    return { id: (typeof b.id === "string" && b.id) ? b.id : uid(), title: (typeof b.title === "string") ? b.title : "",
             updated: finite(b.updated, Date.now()), pinned: !!b.pinned, items: its };
  }
  // boards.json: версия 1 это просто массив досок, версия 2 это { version, boards }
  function parseStore(txt) {
    const j = JSON.parse(txt);
    let arr;
    if (Array.isArray(j)) arr = j;
    else if (j && Array.isArray(j.boards)) {
      if (typeof j.version === "number" && j.version > schemaVersion) throw new Error("формат версии " + j.version + " новее, чем понимает эта версия");
      arr = j.boards;
    } else throw new Error("неожиданная структура файла");
    const out = arr.map(cleanBoard).filter(b => b !== null);
    if (out.length !== arr.length) console.log("notes: пропущено повреждённых досок: " + (arr.length - out.length));
    return out;
  }
  // все три источника (boards.json, notes.json, notes.txt) дали ответ: можно решать, что загружать
  function settle() {
    if (loaded || !(storeDone && oldDone && legacyDone)) return;
    loaded = true;
    if (haveStore) backupProc.running = true;
    else migrate();
    rev++;
    if (boards.length) select(boards[0].id);
    if (open && boards.length === 0) newBoard();
  }
  function select(id) {
    selId = id;
    const b = cur();
    items = b ? b.items.slice() : [];
    previewPath = "";
    confirmDel = "";
    syncing = true;
    titleIn.text = b ? (b.title || "") : "";
    syncing = false;
  }
  function newBoard() {
    const b = { id: uid(), title: "", updated: Date.now(), pinned: false, items: [] };
    boards = [b].concat(boards);
    rev++;
    select(b.id);
    save();
  }
  function setTitle(t) {
    const b = cur();
    if (!b) return;
    b.title = t;
    b.updated = Date.now();
    rev++;
    save();
  }
  function togglePin() {
    const b = cur();
    if (!b) return;
    b.pinned = !b.pinned;
    rev++;
    save();
  }
  function delBoard() {
    const a = boards.filter(b => b.id !== selId);
    boards = a;
    confirmDel = "";
    rev++;
    select(a.length ? a[0].id : "");
    save();
  }
  function typeOf(p) {
    const e = p.split(".").pop().toLowerCase();
    if (e === "gif") return "gif";
    if (["png", "jpg", "jpeg", "webp", "bmp"].indexOf(e) >= 0) return "image";
    if (["wav", "ogg", "oga", "mp3", "flac", "m4a", "opus"].indexOf(e) >= 0) return "audio";
    return "file";
  }
  function addItem(it) {
    if (!cur()) newBoard();
    const b = cur();
    it.id = uid();
    it.z = ++zTop;
    b.items.push(it);
    b.updated = Date.now();
    items = b.items.slice();
    rev++;
    save();
  }
  function addText() {
    const n = items.length % 6;
    addItem({ type: "text", x: 40 + n * 28, y: 40 + n * 28, w: 300, h: 200, text: "" });
  }
  function addFile(p) {
    const t = typeOf(p);
    const n = items.length % 6;
    addItem({ type: t, x: 60 + n * 28, y: 60 + n * 28, w: t === "audio" ? 260 : 280, h: t === "audio" ? 96 : 210, path: p, name: p.split("/").pop() });
  }
  function patchItem(id, props) {
    const b = cur();
    if (!b) return;
    for (let i = 0; i < b.items.length; i++) {
      if (b.items[i].id === id) {
        Object.assign(b.items[i], props);
        b.updated = Date.now();
        save();
        return;
      }
    }
  }
  function delItem(id) {
    const b = cur();
    if (!b) return;
    b.items = b.items.filter(i => i.id !== id);
    items = b.items.slice();
    b.updated = Date.now();
    rev++;
    save();
  }
  function migrate() {
    let arr = [];
    try {
      if (oldStore.loaded) {
        const old = JSON.parse(oldStore.text());
        if (!Array.isArray(old)) throw new Error("notes.json: ожидался массив");
        arr = old.map(n => {
          if (!n || typeof n !== "object") return null;
          const its = [];
          if (n.text) its.push({ id: uid(), type: "text", x: 40, y: 40, w: 340, h: 240, z: 1, text: String(n.text) });
          (Array.isArray(n.files) ? n.files : []).forEach((f, k) => its.push({ id: uid(), type: f.type, x: 400 + (k % 2) * 250, y: 40 + Math.floor(k / 2) * 220, w: f.type === "audio" ? 260 : 230, h: f.type === "audio" ? 96 : 190, z: 2 + k, path: f.path, name: f.name }));
          return { id: n.id, title: n.title, updated: n.updated, pinned: !!n.pinned, items: its };
        }).map(cleanBoard).filter(b => b !== null);
        console.log("notes: миграция notes.json, досок: " + arr.length);
      }
    } catch (e) { console.log("notes: миграция notes.json не удалась: " + e); msg = "не удалось перенести старые заметки (notes.json остался на месте)"; arr = []; }
    if (arr.length === 0 && legacy.loaded && legacy.text().trim()) {
      arr.push({ id: uid(), title: "Заметка", updated: Date.now(), pinned: false, items: [{ id: uid(), type: "text", x: 40, y: 40, w: 360, h: 260, z: 1, text: legacy.text().trim() }] });
      console.log("notes: миграция notes.txt");
    }
    boards = arr;
    if (arr.length) save();
  }
  function runMedia(kind) {
    if (mediaProc.running) return;
    msg = "";
    if (kind === "pick") picking = true;
    if (kind === "record") { if (!cur()) newBoard(); recording = true; }
    mediaProc.command = ["bash", media, kind];
    mediaProc.running = true;
  }
  function toggleRecord() {
    if (recording) stopRec.running = true;
    else runMedia("record");
  }
  function startPlay(p) {
    playing = p;
    playProc.command = ["bash", media, "play", p];
    playProc.running = true;
  }
  // нажатие на ту же заметку останавливает её; на другую: остановить текущую, дождаться выхода, включить выбранную
  function togglePlay(p) {
    if (playProc.running) {
      pendingPlay = (playing === p) ? "" : p;
      stopPlay.running = true;
      return;
    }
    startPlay(p);
  }

  onOpenChanged: {
    if (!open) {
      previewPath = "";
      if (recording) stopRec.running = true;
      if (playProc.running) stopPlay.running = true;
      return;
    }
    if (loaded && boards.length === 0) newBoard();
  }

  IpcHandler {
    target: "notes"
    function toggle(): void { nt.open = !nt.open }
    function show(): void { nt.open = true }
    function hide(): void { nt.open = false }
  }

  FileView {
    id: store
    path: nt.dir + "/boards.json"
    printErrors: false
    onLoaded: {
      try {
        nt.boards = nt.parseStore(store.text());
        nt.haveStore = true;
        let z = 1;
        nt.boards.forEach(b => b.items.forEach(i => { if ((i.z || 0) > z) z = i.z; }));
        nt.zTop = z;
      } catch (e) {
        console.log("boards.json: " + e);
        nt.boards = [];
        nt.haveStore = false;
        // повреждённый файл не затираем молча: сохраняем копию рядом
        corruptProc.running = true;
        nt.msg = "boards.json повреждён, копия сохранена рядом (boards.json.corrupt-…)";
      }
      nt.storeDone = true;
      nt.settle();
    }
    onLoadFailed: { nt.storeDone = true; nt.settle(); }
  }
  FileView { id: oldStore; path: nt.dir + "/notes.json"; printErrors: false; onLoaded: { nt.oldDone = true; nt.settle(); } onLoadFailed: { nt.oldDone = true; nt.settle(); } }
  FileView { id: legacy; path: nt.home + "/.config/quickshell/notes.txt"; printErrors: false; onLoaded: { nt.legacyDone = true; nt.settle(); } onLoadFailed: { nt.legacyDone = true; nt.settle(); } }
  Process { id: backupProc; command: ["sh", "-c", '[ -f "$1" ] && cp -f -- "$1" "$1.bak"', "_", nt.dir + "/boards.json"] }
  Process { id: corruptProc; command: ["sh", "-c", 'cp -f -- "$1" "$1.corrupt-$(date +%Y%m%d-%H%M%S)"', "_", nt.dir + "/boards.json"] }

  Timer { id: saveTimer; interval: 500; onTriggered: { if (nt.loaded) nt.flush(); else saveTimer.restart(); } }
  Timer { id: confirmTimer; interval: 3000; onTriggered: nt.confirmDel = "" }
  // только предупреждение: источники данных обязаны ответить сигналом loaded или loadFailed
  Timer {
    interval: 5000
    running: true
    onTriggered: { if (!nt.loaded) { console.log("notes: данные не загрузились за 5 с"); nt.msg = "заметки ещё не загрузились"; } }
  }

  Process {
    id: mediaProc
    stdout: StdioCollector {
      onStreamFinished: {
        const out = text.trim().split("\n").filter(x => x);
        const last = out.length ? out[out.length - 1] : "";
        if (last.indexOf("ERR:") === 0) nt.msg = last.slice(4);
        else if (last) { nt.addFile(last); nt.msg = ""; }
      }
    }
    onExited: { nt.picking = false; nt.recording = false; }
  }
  Process { id: stopRec; command: ["bash", nt.media, "stop"] }
  Process {
    id: playProc
    stdout: StdioCollector {
      onStreamFinished: { const t = text.trim(); if (t.indexOf("ERR:") === 0) nt.msg = t.slice(4); }
    }
    onExited: {
      nt.playing = "";
      if (nt.pendingPlay !== "") { const p = nt.pendingPlay; nt.pendingPlay = ""; nt.startPlay(p); }
    }
  }
  Process { id: stopPlay; command: ["bash", nt.media, "stopplay"] }

  component Txt: Text {
    color: Theme.fg
    font.family: nt.ff
  }

  component Pill: Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    signal clicked()
    width: lbl.implicitWidth + 24
    height: 34
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

  component CItem: Item {
    id: it
    required property var modelData
    readonly property string itype: modelData.type
    readonly property bool hov: hh.hovered
    x: modelData.x
    y: modelData.y
    width: modelData.w
    height: modelData.h
    z: modelData.z || 1
    opacity: 0
    scale: 0.9
    transformOrigin: Item.Center
    Component.onCompleted: { opacity = 1; scale = 1; }
    Behavior on opacity { NumberAnimation { duration: 240 } }
    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
    HoverHandler { id: hh }

    Rectangle {
      anchors.fill: parent
      radius: 16
      visible: it.itype === "text" || it.itype === "audio"
      color: Theme.surface
      border.color: (it.hov || te.activeFocus) ? Theme.dim : Theme.line
      Behavior on border.color { ColorAnimation { duration: 150 } }
    }
    Rectangle {
      anchors.fill: parent
      radius: 16
      visible: it.itype === "image" || it.itype === "gif"
      color: "transparent"
      border.color: it.hov ? Theme.dim : "transparent"
    }

    Image {
      anchors.fill: parent
      anchors.margins: 3
      visible: it.itype === "image"
      source: it.itype === "image" ? "file://" + it.modelData.path : ""
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      sourceSize.width: 1024
    }
    AnimatedImage {
      anchors.fill: parent
      anchors.margins: 3
      visible: it.itype === "gif"
      source: it.itype === "gif" ? "file://" + it.modelData.path : ""
      fillMode: Image.PreserveAspectFit
      playing: nt.open
      asynchronous: true
    }

    TextEdit {
      id: te
      x: 14
      y: 30
      width: parent.width - 28
      height: parent.height - 42
      visible: it.itype === "text"
      enabled: it.itype === "text"
      wrapMode: TextEdit.Wrap
      color: Theme.fg
      selectionColor: Theme.line
      selectedTextColor: Theme.bright
      selectByMouse: true
      clip: true
      font.family: nt.ff
      font.pixelSize: 15
      text: it.modelData.text || ""
      onTextChanged: { if (activeFocus) nt.patchItem(it.modelData.id, { text: text }) }
    }

    Column {
      visible: it.itype === "audio"
      anchors.centerIn: parent
      anchors.verticalCenterOffset: 6
      spacing: 8
      Txt { width: it.width - 28; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle; text: it.modelData.name || ""; color: Theme.dim; font.pixelSize: 11 }
      Pill {
        anchors.horizontalCenter: parent.horizontalCenter
        label: nt.playing === it.modelData.path ? "■ стоп" : "▶ слушать"
        active: nt.playing === it.modelData.path
        onClicked: nt.togglePlay(it.modelData.path)
      }
    }

    // перетаскивание: у текста и аудио за верхнюю полоску, у фото и GIF за всю карточку
    MouseArea {
      id: dragMa
      width: parent.width
      height: (it.itype === "text" || it.itype === "audio") ? 26 : parent.height
      cursorShape: Qt.SizeAllCursor
      property real sx: 0
      property real sy: 0
      property real ox: 0
      property real oy: 0
      onPressed: (m) => {
        const p = mapToItem(it.parent, m.x, m.y);
        sx = p.x; sy = p.y; ox = it.x; oy = it.y;
        nt.zTop++;
        it.z = nt.zTop;
      }
      onPositionChanged: (m) => {
        if (!pressed) return;
        const p = mapToItem(it.parent, m.x, m.y);
        it.x = Math.max(-it.width + 50, Math.min(it.parent.width - 50, ox + p.x - sx));
        it.y = Math.max(0, Math.min(it.parent.height - 30, oy + p.y - sy));
      }
      onReleased: nt.patchItem(it.modelData.id, { x: it.x, y: it.y, z: it.z })
      onDoubleClicked: { if (it.itype === "image" || it.itype === "gif") nt.previewPath = it.modelData.path; }
    }
    Rectangle {
      visible: it.itype === "text" || it.itype === "audio"
      x: parent.width / 2 - 14
      y: 9
      width: 28
      height: 4
      radius: 2
      color: Theme.faint
    }

    // удалить
    Rectangle {
      visible: it.hov
      z: 20
      width: 24
      height: 24
      radius: 12
      color: Qt.rgba(0, 0, 0, 0.65)
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.margins: 6
      Txt { anchors.centerIn: parent; text: "×"; font.pixelSize: 15 }
      MouseArea { anchors.fill: parent; onClicked: nt.delItem(it.modelData.id) }
    }

    // изменить размер: ширина и высота независимо
    Rectangle {
      visible: it.hov
      z: 20
      width: 18
      height: 18
      radius: 6
      color: Theme.fg
      opacity: 0.85
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: 4
      MouseArea {
        anchors.fill: parent
        anchors.margins: -5
        cursorShape: Qt.SizeFDiagCursor
        property real sx: 0
        property real sy: 0
        property real ow: 0
        property real oh: 0
        onPressed: (m) => {
          const p = mapToItem(it.parent, m.x, m.y);
          sx = p.x; sy = p.y; ow = it.width; oh = it.height;
        }
        onPositionChanged: (m) => {
          if (!pressed) return;
          const p = mapToItem(it.parent, m.x, m.y);
          it.width = Math.max(90, Math.min(it.parent.width, ow + p.x - sx));
          it.height = Math.max(70, Math.min(it.parent.height, oh + p.y - sy));
        }
        onReleased: nt.patchItem(it.modelData.id, { w: it.width, h: it.height })
      }
    }
  }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: (nt.open || box.opacity > 0.01) && !nt.picking
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notes"
    WlrLayershell.keyboardFocus: nt.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: { if (nt.previewPath !== "") nt.previewPath = ""; else nt.open = false; }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        opacity: nt.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
      }
      MouseArea { anchors.fill: parent; onClicked: nt.open = false }

      Rectangle {
        id: box
        width: Math.min(parent.width - 80, 1300)
        height: Math.min(parent.height - 80, 780)
        anchors.centerIn: parent
        radius: 26
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
        border.color: Theme.line
        opacity: nt.open ? 1 : 0
        scale: nt.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 240 } }
        Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Txt { x: 28; y: 22; text: "заметки"; font.pixelSize: 20 }
        Txt { x: 128; y: 28; text: nt.boards.length + " досок"; color: Theme.muted; font.pixelSize: 12 }
        Pill { anchors.right: parent.right; anchors.rightMargin: 24; y: 18; label: "закрыть  (SUPER+O)"; onClicked: nt.open = false }

        // ----- список досок -----
        Column {
          x: 24
          y: 70
          width: 250
          height: box.height - 94
          spacing: 10
          Row {
            spacing: 8
            Rectangle {
              width: 150
              height: 34
              radius: 12
              color: Theme.bg2
              border.color: Theme.line
              TextInput {
                id: searchIn
                anchors.fill: parent
                anchors.margins: 9
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: nt.ff
                font.pixelSize: 13
                clip: true
                onTextChanged: nt.query = text
              }
              Txt { anchors.fill: parent; anchors.margins: 9; verticalAlignment: Text.AlignVCenter; text: "поиск"; color: Theme.muted; font.pixelSize: 12; visible: searchIn.text === "" }
            }
            Pill { label: "+ доска"; onClicked: nt.newBoard() }
          }
          ListView {
            id: list
            width: parent.width
            height: parent.height - 44
            clip: true
            spacing: 6
            model: nt.sorted
            delegate: Rectangle {
              width: list.width
              height: 58
              radius: 14
              color: modelData.id === nt.selId ? Theme.line : (lma.containsMouse ? Theme.surface : "transparent")
              border.color: modelData.id === nt.selId ? Theme.dim : "transparent"
              Behavior on color { ColorAnimation { duration: 140 } }
              Column {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28
                spacing: 3
                Txt { width: parent.width; elide: Text.ElideRight; text: (modelData.pinned ? "★ " : "") + (modelData.title || "без названия"); font.pixelSize: 14 }
                Txt { text: Qt.formatDateTime(new Date(modelData.updated), "dd.MM HH:mm") + "  ·  объектов: " + modelData.items.length; color: Theme.dim; font.pixelSize: 11 }
              }
              MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: nt.select(modelData.id) }
            }
          }
        }

        // ----- доска -----
        Txt { x: 300; y: 100; visible: nt.selId === ""; text: "нет досок, нажми «+ доска»"; color: Theme.muted; font.pixelSize: 14 }
        Column {
          id: right
          x: 296
          y: 70
          width: box.width - 296 - 24
          spacing: 10
          visible: nt.selId !== ""

          Flow {
            id: toolbar
            width: parent.width
            spacing: 8
            Rectangle {
              width: 230
              height: 34
              radius: 12
              color: Theme.bg2
              border.color: Theme.line
              TextInput {
                id: titleIn
                anchors.fill: parent
                anchors.margins: 9
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: nt.ff
                font.pixelSize: 15
                clip: true
                selectByMouse: true
                onTextChanged: { if (!nt.syncing) nt.setTitle(text) }
              }
              Txt { anchors.fill: parent; anchors.margins: 9; verticalAlignment: Text.AlignVCenter; text: "название доски"; color: Theme.muted; font.pixelSize: 13; visible: titleIn.text === "" }
            }
            Pill { label: "+ текст"; onClicked: nt.addText() }
            Pill { label: "из буфера"; onClicked: nt.runMedia("paste") }
            Pill { label: "файл…"; onClicked: nt.runMedia("pick") }
            Pill { label: nt.recording ? "■ стоп записи" : "● запись"; active: nt.recording; onClicked: nt.toggleRecord() }
            Pill { label: (nt.cur() && nt.cur().pinned) ? "открепить" : "закрепить"; active: !!(nt.cur() && nt.cur().pinned); onClicked: nt.togglePin() }
            Pill {
              label: nt.confirmDel === nt.selId ? "точно удалить?" : "удалить доску"
              active: nt.confirmDel === nt.selId
              onClicked: {
                if (nt.confirmDel === nt.selId) nt.delBoard();
                else { nt.confirmDel = nt.selId; confirmTimer.restart(); }
              }
            }
            Txt {
              height: 34
              verticalAlignment: Text.AlignVCenter
              text: nt.recording ? "● идёт запись…" : nt.msg
              color: Theme.dim
              font.pixelSize: 12
              SequentialAnimation on opacity {
                running: nt.recording
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
              }
            }
          }

          Rectangle {
            id: canvas
            width: parent.width
            height: box.height - 70 - toolbar.height - 10 - 24
            radius: 16
            color: Theme.bg2
            border.color: Theme.line
            clip: true

            Canvas {
              id: dots
              anchors.fill: parent
              onPaint: {
                const c = getContext("2d");
                c.reset();
                c.fillStyle = Theme.line.toString();
                for (let x = 14; x < width; x += 28)
                  for (let y = 14; y < height; y += 28)
                    c.fillRect(x, y, 2, 2);
              }
              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()
              Connections { target: Theme; function onLineChanged() { dots.requestPaint() } }
            }
            MouseArea { anchors.fill: parent; z: -1; onClicked: canvas.forceActiveFocus() }
            Txt {
              anchors.centerIn: parent
              visible: nt.items.length === 0
              text: "пустая доска: добавь текст, фото, GIF или голосовое"
              color: Theme.muted
              font.pixelSize: 14
            }
            Repeater {
              model: nt.items
              delegate: CItem { }
            }
          }
        }

        // предпросмотр
        Rectangle {
          anchors.fill: parent
          radius: 26
          color: Qt.rgba(0, 0, 0, 0.92)
          visible: nt.previewPath !== ""
          z: 40
          Image {
            anchors.fill: parent
            anchors.margins: 30
            visible: nt.previewPath !== "" && nt.typeOf(nt.previewPath) !== "gif"
            source: visible ? "file://" + nt.previewPath : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }
          AnimatedImage {
            anchors.fill: parent
            anchors.margins: 30
            visible: nt.previewPath !== "" && nt.typeOf(nt.previewPath) === "gif"
            source: visible ? "file://" + nt.previewPath : ""
            fillMode: Image.PreserveAspectFit
            playing: visible
          }
          MouseArea { anchors.fill: parent; onClicked: nt.previewPath = "" }
        }
      }
    }
  }
}
