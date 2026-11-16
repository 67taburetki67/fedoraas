import QtQuick

Item {
  id: w
  property string src: ""
  property bool gif: false
  property bool active: true
  Image {
    anchors.fill: parent
    visible: !w.gif
    source: (!w.gif && w.src !== "") ? "file://" + w.src : ""
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    sourceSize.width: 1280
  }
  AnimatedImage {
    anchors.fill: parent
    visible: w.gif
    source: (w.gif && w.src !== "") ? "file://" + w.src : ""
    fillMode: Image.PreserveAspectFit
    playing: w.active
    asynchronous: true
  }
}
