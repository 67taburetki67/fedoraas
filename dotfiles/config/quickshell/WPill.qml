import QtQuick

Rectangle {
  id: pill
  property string label: ""
  property bool active: false
  property real u: 1.0
  signal clicked()
  width: lbl.implicitWidth + 24 * u
  height: 32 * u
  radius: 12 * u
  color: active ? Theme.fg : (pma.containsMouse ? Theme.line : Theme.surface)
  border.color: Theme.line
  Behavior on color { ColorAnimation { duration: 150 } }
  WTxt {
    id: lbl
    anchors.centerIn: parent
    text: pill.label
    font.pixelSize: 13 * pill.u
    color: pill.active ? Theme.bg : Theme.fg
  }
  MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: pill.clicked() }
}
