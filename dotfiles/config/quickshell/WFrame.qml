import QtQuick

Item {
  id: frame

  property var sh
  property string kind: "w"
  property string gid: ""
  property var g
  property bool card: true
  property bool deletable: false
  property int idx: 0
  default property alias contents: inner.data

  readonly property real pw: parent ? parent.width : 0
  readonly property real ph: parent ? parent.height : 0
  readonly property real aVal: (g && g.a !== undefined) ? g.a : 1.0
  readonly property real bgVal: (g && g.bg !== undefined) ? g.bg : 0.6
  readonly property bool edit: !!sh && sh.editing
  property real appear: (!!sh && sh.shown) ? 1 : 0
  property real lift: 0

  visible: !!g && g.on !== false
  x: g ? g.x * pw : 0
  y: g ? g.y * ph : 0
  width: g ? Math.max(40, g.w * pw) : 0
  height: g ? Math.max(30, g.h * ph) : 0
  opacity: aVal * appear
  transform: Translate { y: (1 - frame.appear) * 28 - frame.lift }

  Behavior on appear {
    SequentialAnimation {
      PauseAnimation { duration: (frame.sh && frame.sh.shown) ? frame.idx * 40 : 0 }
      NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
    }
  }
  Behavior on lift { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
  HoverHandler { onHoveredChanged: frame.lift = (hovered && !frame.edit) ? 5 : 0 }

  WCard { anchors.fill: parent; visible: frame.card; bgA: frame.bgVal }
  Item { id: inner; anchors.fill: parent }

  Rectangle {
    anchors.fill: parent
    visible: frame.edit
    color: "transparent"
    border.color: Theme.fg
    border.width: 1
    radius: 14
  }

  // перетаскивание
  MouseArea {
    anchors.fill: parent
    enabled: frame.edit
    z: 5
    property real sx: 0
    property real sy: 0
    property real ox: 0
    property real oy: 0
    onPressed: (m) => { const p = mapToItem(frame.parent, m.x, m.y); sx = p.x; sy = p.y; ox = frame.g.x; oy = frame.g.y; }
    onPositionChanged: (m) => {
      if (!pressed) return;
      const p = mapToItem(frame.parent, m.x, m.y);
      frame.sh.setGeom(frame.kind, frame.gid, "x", Math.max(0, Math.min(0.95, ox + (p.x - sx) / frame.pw)));
      frame.sh.setGeom(frame.kind, frame.gid, "y", Math.max(0, Math.min(0.95, oy + (p.y - sy) / frame.ph)));
    }
    onReleased: frame.sh.saveConfig()
  }

  // ширина: правый край
  Rectangle {
    visible: frame.edit
    z: 6
    width: 10
    height: 44
    radius: 5
    color: Theme.fg
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    MouseArea {
      anchors.fill: parent
      anchors.margins: -8
      property real sx: 0
      property real ow: 0
      onPressed: (m) => { sx = mapToItem(frame.parent, m.x, m.y).x; ow = frame.g.w; }
      onPositionChanged: (m) => {
        if (!pressed) return;
        const dx = mapToItem(frame.parent, m.x, m.y).x - sx;
        frame.sh.setGeom(frame.kind, frame.gid, "w", Math.max(0.05, Math.min(0.9, ow + dx / frame.pw)));
      }
      onReleased: frame.sh.saveConfig()
    }
  }

  // высота: нижний край
  Rectangle {
    visible: frame.edit
    z: 6
    width: 44
    height: 10
    radius: 5
    color: Theme.fg
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    MouseArea {
      anchors.fill: parent
      anchors.margins: -8
      property real sy: 0
      property real oh: 0
      onPressed: (m) => { sy = mapToItem(frame.parent, m.x, m.y).y; oh = frame.g.h; }
      onPositionChanged: (m) => {
        if (!pressed) return;
        const dy = mapToItem(frame.parent, m.x, m.y).y - sy;
        frame.sh.setGeom(frame.kind, frame.gid, "h", Math.max(0.05, Math.min(0.95, oh + dy / frame.ph)));
      }
      onReleased: frame.sh.saveConfig()
    }
  }

  // угол: обе стороны
  Rectangle {
    visible: frame.edit
    z: 7
    width: 22
    height: 22
    radius: 6
    color: Theme.fg
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    MouseArea {
      anchors.fill: parent
      anchors.margins: -6
      property real sx: 0
      property real sy: 0
      property real ow: 0
      property real oh: 0
      onPressed: (m) => { const p = mapToItem(frame.parent, m.x, m.y); sx = p.x; sy = p.y; ow = frame.g.w; oh = frame.g.h; }
      onPositionChanged: (m) => {
        if (!pressed) return;
        const p = mapToItem(frame.parent, m.x, m.y);
        frame.sh.setGeom(frame.kind, frame.gid, "w", Math.max(0.05, Math.min(0.9, ow + (p.x - sx) / frame.pw)));
        frame.sh.setGeom(frame.kind, frame.gid, "h", Math.max(0.05, Math.min(0.95, oh + (p.y - sy) / frame.ph)));
      }
      onReleased: frame.sh.saveConfig()
    }
  }

  // удалить наклейку
  Rectangle {
    visible: frame.edit && frame.deletable
    z: 9
    width: 26
    height: 26
    radius: 13
    color: Qt.rgba(0, 0, 0, 0.7)
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.margins: 6
    WTxt { anchors.centerIn: parent; text: "×"; font.pixelSize: 16 }
    MouseArea { anchors.fill: parent; onClicked: frame.sh.delSticker(frame.gid) }
  }

  // две прозрачности: вид и фон
  Rectangle {
    visible: frame.edit
    z: 8
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 8
    anchors.rightMargin: 34
    anchors.bottomMargin: 8
    height: frame.card ? 50 : 28
    radius: 10
    color: Qt.rgba(0, 0, 0, 0.62)
    Column {
      anchors.fill: parent
      anchors.margins: 4
      spacing: 2
      Row {
        width: parent.width  // rowfix
        height: 20
        spacing: 6
        WTxt { text: "вид"; width: 34; height: 20; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 10 }
        WSld {
          width: parent.width - 40
          height: 20
          source: frame.aVal
          onMoved: v => { frame.sh.setGeom(frame.kind, frame.gid, "a", Math.max(0.2, Math.min(1, v))); frame.sh.saveConfig(); }
        }
      }
      Row {
        width: parent.width  // rowfix
        visible: frame.card
        height: 20
        spacing: 6
        WTxt { text: "фон"; width: 34; height: 20; verticalAlignment: Text.AlignVCenter; color: Theme.dim; font.pixelSize: 10 }
        WSld {
          width: parent.width - 40
          height: 20
          source: frame.bgVal
          onMoved: v => { frame.sh.setGeom(frame.kind, frame.gid, "bg", Math.max(0, Math.min(1, v))); frame.sh.saveConfig(); }
        }
      }
    }
  }
}
