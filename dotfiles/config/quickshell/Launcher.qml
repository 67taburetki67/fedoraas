import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: ln

  property bool open: false
  property string query: ""
  property int sel: 0
  property string hint: ""
  property string confirmKey: ""
  property var usage: ({})
  property var themes: []
  readonly property string ff: "JetBrains Mono"
  readonly property string home: Quickshell.env("HOME")
  readonly property string terminal: "foot"
  readonly property string bin: home + "/.local/bin"

  function sc(text, q) {
    if (!text) return 0;
    text = String(text).toLowerCase();
    if (text === q) return 120;
    if (text.indexOf(q) === 0) return 100;
    if (text.indexOf(" " + q) >= 0) return 70;
    if (text.indexOf(q) >= 0) return 45;
    let k = 0;
    for (let c = 0; c < text.length && k < q.length; c++) if (text[c] === q[k]) k++;
    return k === q.length ? 18 : 0;
  }

  function actionList(th) {
    const ipc = n => ["quickshell", "ipc", "call", n, "show"];
    const a = [
      { name: "Заметки", sub: "доски заметок", kw: "notes заметки доска", cmd: ipc("notes"), key: "a:notes" },
      { name: "Плеер", sub: "музыка и визуализатор", kw: "player music музыка плеер", cmd: ipc("player"), key: "a:player" },
      { name: "Виджеты", sub: "часы, календарь, задачи", kw: "widgets виджеты", cmd: ipc("widgets"), key: "a:widgets" },
      { name: "Быстрые настройки", sub: "Wi-Fi, звук, питание", kw: "settings wifi bluetooth настройки", cmd: ipc("quicksettings"), key: "a:qs" },
      { name: "Шпаргалка клавиш", sub: "все сочетания", kw: "keys cheatsheet бинды клавиши", cmd: ipc("cheatsheet"), key: "a:cheat" },
      { name: "Следующие обои", sub: "в текущей теме", kw: "wallpaper обои", cmd: [ln.bin + "/theme", "wall", "next"], key: "a:wall" },
      { name: "Случайные обои", sub: "в текущей теме", kw: "wallpaper обои random", cmd: [ln.bin + "/theme", "wall", "random"], key: "a:wallr" },
      { name: "Заблокировать", sub: "экран блокировки", kw: "lock блокировка", cmd: ["sh", "-c", "command -v hyprlock >/dev/null 2>&1 && setsid -f hyprlock || notify-send 'Экран блокировки' 'hyprlock не установлен: ./install.sh --with-lock'"], key: "a:lock" },
      { name: "Сон", sub: "приостановить систему", kw: "suspend sleep сон", cmd: ["systemctl", "suspend"], key: "a:sleep" },
      { name: "Выйти из сессии", sub: "закрыть Hyprland", kw: "logout exit выход", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], key: "a:exit", confirm: true },
      { name: "Перезагрузка", sub: "перезагрузить компьютер", kw: "reboot restart перезагрузка", cmd: ["systemctl", "reboot"], key: "a:reboot", confirm: true },
      { name: "Выключить", sub: "выключить компьютер", kw: "poweroff shutdown выключить", cmd: ["systemctl", "poweroff"], key: "a:off", confirm: true }
    ];
    (th || []).forEach(t => a.push({ name: "Тема: " + t, sub: "переключить оформление", kw: "theme тема " + t, cmd: [ln.bin + "/theme", t], key: "a:theme:" + t }));
    return a;
  }

  // Калькулятор без eval: рекурсивный разбор + - * / % ^ (и **), скобки, унарный минус
  function evalExpr(src) {
    const s = src.replace(/\*\*/g, "^");
    let i = 0, depth = 0;
    const peek = () => { while (i < s.length && /\s/.test(s[i])) i++; return s[i]; };
    const number = () => {
      peek();
      const m = /^(\d+\.?\d*|\.\d+)/.exec(s.slice(i));
      if (!m) throw new Error("ожидалось число");
      i += m[0].length;
      return parseFloat(m[0]);
    };
    const atom = () => {
      if (peek() === "(") {
        if (++depth > 40) throw new Error("слишком глубокая вложенность");
        i++;
        const v = expr();
        if (peek() !== ")") throw new Error("нет закрывающей скобки");
        i++; depth--;
        return v;
      }
      return number();
    };
    const power = () => { const b = atom(); if (peek() === "^") { i++; return Math.pow(b, unary()); } return b; };
    const unary = () => { const c = peek(); if (c === "-") { i++; return -unary(); } if (c === "+") { i++; return unary(); } return power(); };
    const term = () => {
      let v = unary();
      for (;;) {
        const c = peek();
        if (c === "*") { i++; v *= unary(); }
        else if (c === "/") { i++; v /= unary(); }
        else if (c === "%") { i++; v %= unary(); }
        else return v;
      }
    };
    const expr = () => {
      let v = term();
      for (;;) {
        const c = peek();
        if (c === "+") { i++; v += term(); }
        else if (c === "-") { i++; v -= term(); }
        else return v;
      }
    };
    const r = expr();
    if (peek() !== undefined) throw new Error("лишние символы");
    return r;
  }
  function calc(q0, apps, use, th) {
    const q = q0.trim();
    const low = q.toLowerCase();
    const all = [];

    if (q !== "" && q.length <= 200 && /^=?[0-9\s+\-*\/().,%^]+$/.test(q) && /[+\-*\/^%]/.test(q.replace(/^=/, "").replace(/^\s*-/, ""))) {
      try {
        const v = evalExpr(q.replace(/^=/, "").replace(/,/g, "."));
        if (typeof v === "number" && isFinite(v)) all.push({ kind: "calc", title: String(Math.round(v * 1e10) / 1e10), sub: q + "   (Enter копирует)", icon: "", score: 1000, key: "calc" });
      } catch (e) { }
    }
    if (q.charAt(0) === ">" && q.length > 1) {
      const c = q.slice(1).trim();
      if (c) all.push({ kind: "act", title: "выполнить: " + c, sub: "в оболочке", icon: "", score: 900, key: "cmd", cmd: ["sh", "-c", "setsid -f " + c + " >/dev/null 2>&1"] });
    }
    if (q.charAt(0) === "?" && q.length > 1) {
      const s = q.slice(1).trim();
      if (s) all.push({ kind: "act", title: "искать: " + s, sub: "в браузере", icon: "", score: 900, key: "web", cmd: ["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(s)] });
    }

    const toks = low.split(/\s+/).filter(t => t);
    const fits = (parts) => {
      let total = 0;
      for (let i = 0; i < toks.length; i++) {
        let s = 0;
        for (let j = 0; j < parts.length; j++) s = Math.max(s, sc(parts[j][0], toks[i]) * parts[j][1]);
        if (s <= 0) return -1;
        total += s;
      }
      return total / toks.length;
    };

    for (let i = 0; i < apps.length; i++) {
      const e = apps[i];
      if (e.noDisplay) continue;
      const bonus = Math.min(40, ((use[e.id] || {}).n || 0) * 4);
      let s = bonus;
      if (toks.length > 0) {
        const f = fits([[e.name, 1], [e.genericName, 0.6], [(e.keywords || []).join(" "), 0.5], [e.comment, 0.3], [e.id, 0.4]]);
        if (f < 0) continue;
        s = f + bonus;
      }
      all.push({ kind: "app", entry: e, title: e.name, sub: e.genericName || e.comment || "", icon: e.icon, score: s, key: "app:" + e.id });
    }

    if (toks.length > 0) {
      const acts = actionList(th);
      for (let i = 0; i < acts.length; i++) {
        const a = acts[i];
        const f = fits([[a.name, 1], [a.kw, 0.6]]);
        if (f < 0) continue;
        all.push({ kind: "act", title: a.name, sub: a.sub, icon: "", score: f * 0.95, key: a.key, cmd: a.cmd, confirm: !!a.confirm });
      }
    }
    all.sort((x, y) => (y.score - x.score) || (x.title < y.title ? -1 : (x.title > y.title ? 1 : 0)));
    return all.slice(0, 9);
  }

  readonly property var results: calc(query, DesktopEntries.applications.values, usage, themes)

  function move(d) {
    if (results.length === 0) return;
    sel = (sel + d + results.length) % results.length;
    confirmKey = "";
    hint = "";
  }
  function bump(id) {
    const u = Object.assign({}, usage);
    u[id] = { n: ((u[id] || {}).n || 0) + 1, t: Date.now() };
    usage = u;
    usageFile.setText(JSON.stringify(u));
  }
  function activate(r) {
    if (!r) return;
    if (r.confirm && confirmKey !== r.key) {
      confirmKey = r.key;
      hint = "ещё раз Enter, чтобы подтвердить: " + r.title;
      confirmTimer.restart();
      return;
    }
    open = false;
    if (r.kind === "app") {
      bump(r.entry.id);
      if (r.entry.runInTerminal) Quickshell.execDetached([terminal, "-e"].concat(r.entry.command));
      else r.entry.execute();
    } else if (r.kind === "calc") {
      Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "sh", r.title]);
    } else {
      Quickshell.execDetached(r.cmd);
    }
  }

  onOpenChanged: {
    if (!open) return;
    query = "";
    sel = 0;
    hint = "";
    confirmKey = "";
    input.text = "";
    input.forceActiveFocus();
    if (!themeProc.running) themeProc.running = true;
  }
  onResultsChanged: { if (sel >= results.length) sel = 0; }

  IpcHandler {
    target: "launcher"
    function toggle(): void { ln.open = !ln.open }
    function show(): void { ln.open = true }
    function hide(): void { ln.open = false }
  }

  FileView {
    id: usageFile
    path: ln.home + "/.local/share/quickshell-launcher.json"
    onLoaded: { try { ln.usage = JSON.parse(usageFile.text()); } catch (e) { ln.usage = ({}); } }
  }
  Process {
    id: themeProc
    command: ["bash", ln.bin + "/theme", "list"]
    stdout: StdioCollector { onStreamFinished: ln.themes = text.trim().split("\n").filter(x => x) }
  }
  Timer { id: confirmTimer; interval: 3000; onTriggered: { ln.confirmKey = ""; ln.hint = ""; } }

  component Txt: Text {
    color: Theme.fg
    font.family: ln.ff
  }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: ln.open || card.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: ln.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      focus: true

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
        opacity: ln.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
      }
      MouseArea { anchors.fill: parent; onClicked: ln.open = false }

      Rectangle {
        id: card
        width: 680
        height: col.implicitHeight + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16 + (ln.open ? 0 : -26)
        radius: 24
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.93)
        border.color: Theme.line
        opacity: ln.open ? 1 : 0
        scale: ln.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Column {
          id: col
          x: 14
          y: 14
          width: parent.width - 28
          spacing: 10

          Rectangle {
            width: parent.width
            height: 54
            radius: 16
            color: Theme.bg2
            border.color: Theme.line
            Txt { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "›"; font.pixelSize: 26; color: Theme.dim }
            TextInput {
              id: input
              x: 48
              width: parent.width - 66
              height: parent.height
              verticalAlignment: TextInput.AlignVCenter
              color: Theme.fg
              font.family: ln.ff
              font.pixelSize: 19
              clip: true
              onTextChanged: { ln.query = text; ln.sel = 0; ln.confirmKey = ""; ln.hint = ""; }
              onAccepted: ln.activate(ln.results[ln.sel])
              Keys.onUpPressed: ln.move(-1)
              Keys.onDownPressed: ln.move(1)
              Keys.onTabPressed: ln.move(1)
              Keys.onEscapePressed: ln.open = false
            }
            Txt {
              x: 48
              anchors.verticalCenter: parent.verticalCenter
              visible: input.text === ""
              text: "приложение, действие, 2+2, > команда, ? поиск"
              color: Theme.muted
              font.pixelSize: 16
            }
          }

          Repeater {
            model: ln.results
            Rectangle {
              width: col.width
              height: 50
              radius: 14
              color: index === ln.sel ? Theme.line : "transparent"
              border.color: index === ln.sel ? Theme.dim : "transparent"
              Behavior on color { ColorAnimation { duration: 110 } }

              Rectangle {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 10
                color: Theme.surface
                border.color: Theme.line
                Image {
                  anchors.centerIn: parent
                  width: 24
                  height: 24
                  visible: modelData.kind === "app" && modelData.icon !== ""
                  source: modelData.kind === "app" && modelData.icon !== "" ? "image://icon/" + modelData.icon : ""
                  sourceSize.width: 48
                  sourceSize.height: 48
                  asynchronous: true
                }
                Txt {
                  anchors.centerIn: parent
                  visible: modelData.kind !== "app" || modelData.icon === ""
                  text: modelData.kind === "calc" ? "=" : modelData.title.charAt(0).toUpperCase()
                  color: Theme.dim
                  font.pixelSize: 15
                }
              }
              Column {
                x: 58
                width: parent.width - 58 - 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Txt { width: parent.width; elide: Text.ElideRight; text: modelData.title; font.pixelSize: 15 }
                Txt { width: parent.width; elide: Text.ElideRight; text: modelData.sub; color: Theme.dim; font.pixelSize: 11 }
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: ln.sel = index
                onClicked: { ln.sel = index; ln.activate(modelData); }
              }
            }
          }

          Txt {
            visible: ln.hint !== ""
            width: parent.width
            text: ln.hint
            color: Theme.dim
            font.pixelSize: 12
          }
          Txt {
            visible: ln.results.length === 0 && ln.query !== ""
            text: "ничего не найдено"
            color: Theme.muted
            font.pixelSize: 13
          }
        }
      }
    }
  }
}
