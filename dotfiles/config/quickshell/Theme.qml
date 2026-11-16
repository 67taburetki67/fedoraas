pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: theme

  property color bg: "#0d0d0e"
  property color bg2: "#121213"
  property color surface: "#1a1a1c"
  property color surface2: "#222224"
  property color line: "#2a2a2c"
  property color faint: "#3a3a3d"
  property color muted: "#5a5a5e"
  property color dim: "#8a8a8e"
  property color fg: "#c4c4c6"
  property color bright: "#d0d0d2"
  property bool paws: false

  FileView {
    id: file
    path: Quickshell.env("HOME") + "/.config/themes/colors.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try {
        const j = JSON.parse(file.text());
        theme.bg = j.bg; theme.bg2 = j.bg2; theme.surface = j.surface; theme.surface2 = j.surface2;
        theme.line = j.line; theme.faint = j.faint; theme.muted = j.muted; theme.dim = j.dim;
        theme.fg = j.fg; theme.bright = j.bright;
        theme.paws = j.paws === true;
      } catch (e) { console.log("colors.json: " + e); }
    }
  }
}
