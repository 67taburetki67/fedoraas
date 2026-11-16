import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.55, Math.min(width / 320, height / 300))
  readonly property real m: 16 * u

  WTxt { id: hd; x: w.m; y: w.m; text: "задачи"; color: Theme.dim; font.pixelSize: 13 * w.u }
  WTxt { x: w.m + hd.width + 10 * w.u; y: w.m + 1; text: w.sh.todos.filter(t => !t.done).length + " осталось"; color: Theme.muted; font.pixelSize: 11 * w.u }
  Rectangle {
    id: inp
    x: w.m
    y: w.m + 26 * w.u
    width: w.width - 2 * w.m
    height: 34 * w.u
    radius: 12 * w.u
    color: Theme.bg2
    border.color: Theme.line
    TextInput {
      id: todoIn
      anchors.fill: parent
      anchors.margins: 9 * w.u
      verticalAlignment: TextInput.AlignVCenter
      color: Theme.fg
      font.family: "JetBrains Mono"
      font.pixelSize: 13 * w.u
      clip: true
      onAccepted: { w.sh.addTodo(text); text = ""; }
    }
    WTxt {
      anchors.fill: parent
      anchors.margins: 9 * w.u
      verticalAlignment: Text.AlignVCenter
      text: "новая задача, Enter"
      color: Theme.muted
      font.pixelSize: 12 * w.u
      visible: todoIn.text === "" && !todoIn.activeFocus
    }
  }
  ListView {
    id: lv
    x: w.m
    y: inp.y + inp.height + 8 * w.u
    width: w.width - 2 * w.m
    height: Math.max(0, w.height - y - w.m - 40 * w.u)
    clip: true
    spacing: 4 * w.u
    model: w.sh.todos
    delegate: Item {
      width: lv.width
      height: 28 * w.u
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 18 * w.u
        height: width
        radius: 6 * w.u
        color: modelData.done ? Theme.fg : "transparent"
        border.color: Theme.dim
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: w.sh.toggleTodo(index) }
      }
      WTxt {
        x: 28 * w.u
        width: parent.width - 52 * w.u
        anchors.verticalCenter: parent.verticalCenter
        text: modelData.text
        elide: Text.ElideRight
        color: modelData.done ? Theme.muted : Theme.fg
        font.strikeout: modelData.done
        font.pixelSize: 13 * w.u
      }
      WTxt {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "×"
        color: Theme.muted
        font.pixelSize: 18 * w.u
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: w.sh.delTodo(index) }
      }
    }
  }
  WPill { u: w.u; x: w.m; y: w.height - w.m - height; label: "очистить выполненные"; onClicked: w.sh.clearDone() }
}
