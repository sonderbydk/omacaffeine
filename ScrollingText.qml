import QtQuick
import qs.Commons

// Single-line text in a fixed-width box. When the text is wider than the
// box it glides left, pauses, and glides back, instead of wrapping.
Item {
  id: root

  property string text: ""
  property color color: Color.foreground
  property string fontFamily: Style.font.family
  property real pixelSize: Style.font.bodySmall
  property bool bold: false
  property bool active: true          // owner's on-screen state; stops the glide
  property int pauseMs: 1400
  property real pixelsPerSecond: 28

  // Breathing room on both sides while gliding, so a text that only just
  // overflows still travels a visible distance.
  readonly property string glidePad: "   "
  readonly property bool overflowing: probe.implicitWidth > width + 0.5

  height: label.implicitHeight
  baselineOffset: label.baselineOffset
  clip: true

  // Measures the unpadded text so padding never causes the overflow itself.
  Text {
    id: probe
    visible: false
    text: root.text
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    font.bold: root.bold
    textFormat: Text.PlainText
  }

  Text {
    id: label
    text: root.overflowing ? root.glidePad + root.text + root.glidePad : root.text
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    font.bold: root.bold
    textFormat: Text.PlainText
    elide: Text.ElideNone
  }

  onOverflowingChanged: if (!overflowing) label.x = 0
  onTextChanged: label.x = 0

  SequentialAnimation {
    id: glide
    running: root.overflowing && root.visible && root.active
    loops: Animation.Infinite
    PauseAnimation { duration: root.pauseMs }
    NumberAnimation {
      target: label
      property: "x"
      to: root.width - label.implicitWidth
      duration: Math.max(600, (label.implicitWidth - root.width) / root.pixelsPerSecond * 1000)
      easing.type: Easing.InOutSine
    }
    PauseAnimation { duration: root.pauseMs }
    NumberAnimation {
      target: label
      property: "x"
      to: 0
      duration: Math.max(600, (label.implicitWidth - root.width) / root.pixelsPerSecond * 1000)
      easing.type: Easing.InOutSine
    }
  }
}
