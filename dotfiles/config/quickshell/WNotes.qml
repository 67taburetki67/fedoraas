import QtQuick

Item {
  id: w
  property var sh
  readonly property real u: Math.max(0.55, Math.min(width / 320, height / 260))
  readonly property real m: 16 * u

  WTxt { id: hd; x: w.m; y: w.m; text: "заметки"; color: Theme.dim; font.pixelSize: 13 * w.u }
  WTxt { x: w.m + hd.width + 8 * w.u; y: w.m + 1; text: w.sh.notesCount + " досок"; color: Theme.muted; font.pixelSize: 11 * w.u }
  WTxt {
    x: w.m
    y: w.m + 26 * w.u
    width: w.width - 2 * w.m
    height: Math.max(0, w.height - y - w.m - 42 * w.u)
    wrapMode: Text.Wrap
    elide: Text.ElideRight
    clip: true
    text: w.sh.notesPreview
    font.pixelSize: 13 * w.u
  }
  WPill { u: w.u; x: w.m; y: w.height - w.m - height; label: "открыть заметки"; onClicked: w.sh.openNotes() }
}
