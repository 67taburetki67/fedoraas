import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.5, Math.min(width / 380, height / 170))
  readonly property real m: 16 * u
  readonly property bool showCover: width > 230
  readonly property real cs: Math.max(20, Math.min(height - 2 * m, width * 0.4))

  Rectangle {
    id: cover
    visible: w.showCover
    x: w.m
    y: (w.height - w.cs) / 2
    width: w.cs
    height: w.cs
    radius: 16 * w.u
    color: Theme.surface
    border.color: Theme.line
    clip: true
    Image {
      anchors.fill: parent
      source: w.sh.pArt
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      visible: w.sh.pArt !== ""
    }
    WTxt { anchors.centerIn: parent; text: "♪"; font.pixelSize: w.cs * 0.35; color: Theme.muted; visible: w.sh.pArt === "" }
  }
  Column {
    x: w.showCover ? cover.x + cover.width + 14 * w.u : w.m
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(40, w.width - x - w.m)
    spacing: 6 * w.u
    WTxt { width: parent.width; elide: Text.ElideRight; text: w.sh.pStatus === "none" ? "ничего не играет" : (w.sh.pTitle || "—"); font.pixelSize: 16 * w.u }
    WTxt { width: parent.width; elide: Text.ElideRight; text: w.sh.pArtist; color: Theme.dim; font.pixelSize: 12 * w.u }
    WSld { width: parent.width; height: 24 * w.u; source: w.sh.pLen > 0 ? w.sh.pPos / w.sh.pLen : 0; onMoved: v => w.sh.seekFrac(v) }
    WTxt { text: w.sh.fmt(w.sh.pPos) + " / " + w.sh.fmt(w.sh.pLen); color: Theme.muted; font.pixelSize: 11 * w.u }
    Row {
      spacing: 8 * w.u
      WPill { u: w.u; label: "◀◀"; onClicked: w.sh.player(["previous"]) }
      WPill { u: w.u; label: w.sh.pStatus === "Playing" ? "||" : "▶"; active: w.sh.pStatus === "Playing"; onClicked: w.sh.player(["play-pause"]) }
      WPill { u: w.u; label: "▶▶"; onClicked: w.sh.player(["next"]) }
    }
  }
}
