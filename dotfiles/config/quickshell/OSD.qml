import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
  id: osd

  property bool shown: false
  property string kind: "vol"
  property int level: 0
  readonly property string ff: "JetBrains Mono"
  readonly property var titles: ({ vol: "громкость", muted: "без звука", bri: "яркость" })

  IpcHandler {
    target: "osd"
    function show(k: string, v: int): void {
      osd.kind = k;
      osd.level = v;
      osd.shown = true;
      hideTimer.restart();
    }
  }

  Timer { id: hideTimer; interval: 1400; onTriggered: osd.shown = false }

  PanelWindow {
    anchors { bottom: true }
    margins { bottom: 90 }
    implicitWidth: 320
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    visible: osd.shown || card.opacity > 0.01
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "osd"

    Rectangle {
      id: card
      anchors.fill: parent
      radius: 20
      color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85)
      border.color: Theme.line
      opacity: osd.shown ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

      Row {
        anchors.centerIn: parent
        spacing: 16
        Text {
          width: 96
          anchors.verticalCenter: parent.verticalCenter
          text: osd.titles[osd.kind] || osd.kind
          color: Theme.dim
          font.family: osd.ff
          font.pixelSize: 13
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 130
          height: 6
          radius: 3
          color: Theme.line
          Rectangle {
            width: osd.kind === "muted" ? 0 : parent.width * Math.min(100, osd.level) / 100
            height: parent.height
            radius: 3
            color: Theme.fg
            Behavior on width { NumberAnimation { duration: 120 } }
          }
        }
        Text {
          width: 44
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
          text: osd.kind === "muted" ? "—" : osd.level + "%"
          color: Theme.fg
          font.family: osd.ff
          font.pixelSize: 13
        }
      }
    }
  }
}
