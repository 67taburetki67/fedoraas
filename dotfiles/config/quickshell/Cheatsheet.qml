import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: cs

  property bool shown: false
  property var groups: []
  property string query: ""
  readonly property string ff: "JetBrains Mono"

  function match(it) {
    const q = query.trim().toLowerCase();
    return q === "" || (it.keys + " " + it.desc).toLowerCase().indexOf(q) >= 0;
  }
  function count(g) { return g.items.filter(it => match(it)).length; }

  FileView {
    id: kbFile
    path: Quickshell.env("HOME") + "/.config/quickshell/keybinds.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { cs.groups = JSON.parse(kbFile.text()); }
      catch (e) { cs.groups = [{ title: "ошибка в keybinds.json", items: [{ keys: "", desc: String(e) }] }]; }
    }
  }

  IpcHandler {
    target: "cheatsheet"
    function toggle(): void { cs.shown = !cs.shown }
    function show(): void { cs.shown = true }
    function hide(): void { cs.shown = false }
  }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: cs.shown || box.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "cheatsheet"
    WlrLayershell.keyboardFocus: cs.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: cs.shown = false

      Connections {
        target: cs
        function onShownChanged() {
          if (cs.shown) { search.text = ""; search.forceActiveFocus(); }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        opacity: cs.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
      }
      MouseArea { anchors.fill: parent; onClicked: cs.shown = false }

      Rectangle {
        id: box
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1000)
        height: Math.min(parent.height - 80, 680)
        radius: 26
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
        border.color: Theme.line
        opacity: cs.shown ? 1 : 0
        scale: cs.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Text { x: 28; y: 24; text: "шпаргалка клавиш"; color: Theme.fg; font.family: cs.ff; font.pixelSize: 20 }
        Rectangle {
          anchors.right: parent.right
          anchors.rightMargin: 28
          y: 18
          width: 260
          height: 36
          radius: 12
          color: Theme.bg2
          border.color: Theme.line
          TextInput {
            id: search
            anchors.fill: parent
            anchors.margins: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            font.family: cs.ff
            font.pixelSize: 13
            clip: true
            onTextChanged: cs.query = text
          }
          Text {
            anchors.fill: parent
            anchors.margins: 10
            verticalAlignment: Text.AlignVCenter
            text: "поиск…"
            color: Theme.muted
            font.family: cs.ff
            font.pixelSize: 12
            visible: search.text === ""
          }
        }

        Flickable {
          x: 28
          y: 72
          width: parent.width - 56
          height: parent.height - 72 - 24
          contentWidth: width
          contentHeight: flow.height
          clip: true
          Flow {
            id: flow
            width: parent.width
            spacing: 24
            Repeater {
              model: cs.groups
              Column {
                visible: cs.count(modelData) > 0
                width: (flow.width - 24) / 2
                spacing: 8
                Text { text: modelData.title; color: Theme.dim; font.family: cs.ff; font.pixelSize: 13 }
                Repeater {
                  model: modelData.items
                  Row {
                    visible: cs.match(modelData)
                    width: parent.width
                    spacing: 12
                    Rectangle {
                      width: 200
                      height: 28
                      radius: 9
                      color: Theme.surface
                      border.color: Theme.line
                      Text { anchors.centerIn: parent; text: modelData.keys; color: Theme.fg; font.family: cs.ff; font.pixelSize: 12 }
                    }
                    Text {
                      width: parent.width - 212
                      height: 28
                      verticalAlignment: Text.AlignVCenter
                      elide: Text.ElideRight
                      text: modelData.desc
                      color: Theme.dim
                      font.family: cs.ff
                      font.pixelSize: 12
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
