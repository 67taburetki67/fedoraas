import QtQuick

Rectangle {
  property real bgA: 0.6
  radius: 20
  color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bgA)
  border.color: Qt.rgba(Theme.line.r, Theme.line.g, Theme.line.b, Math.min(1, bgA * 1.6))
  border.width: 1
  MouseArea { anchors.fill: parent }
}
