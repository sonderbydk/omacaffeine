import QtQuick
import qs.Commons

// The hero: a mug that fills with coffee as the day's caffeine approaches
// the daily limit. Outline and label follow the theme; the liquid stays
// coffee-brown because some things are sacred. Past the limit the crema
// turns the theme's urgent colour.
Item {
  id: root

  property real level: 0            // 0..1+ of the daily limit
  property color foreground: Color.foreground
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family
  property string label: ""
  property string sublabel: ""
  property bool steaming: level > 0.02

  readonly property real clampedLevel: Math.max(0, Math.min(1, level))
  readonly property bool overLimit: level > 1
  readonly property color liquid: "#5a3a26"
  readonly property color liquidDeep: "#3d2618"
  readonly property color crema: overLimit ? urgent : "#c39a6b"

  // Geometry shared by the canvas and the centred label. The cup body sits
  // slightly left of centre so the handle has room on the right.
  readonly property real bodyW: Math.min(width * 0.62, height * 0.62)
  readonly property real bodyH: bodyW * 1.05
  readonly property real bodyX: (width - bodyW) / 2 - bodyW * 0.08
  readonly property real bodyBottom: height - Math.max(6, height * 0.06)
  readonly property real bodyTop: bodyBottom - bodyH
  readonly property real lineW: Math.max(2, bodyW * 0.035)

  property real shownLevel: 0
  property real phase: 0

  Behavior on shownLevel {
    NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
  }
  onLevelChanged: shownLevel = clampedLevel
  Component.onCompleted: shownLevel = clampedLevel
  onShownLevelChanged: canvas.requestPaint()
  onForegroundChanged: canvas.requestPaint()
  onOverLimitChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Timer {
    interval: 70
    running: root.visible && root.steaming
    repeat: true
    onTriggered: {
      root.phase = (root.phase + 0.08) % (Math.PI * 2)
      canvas.requestPaint()
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      var w = width, h = height
      ctx.clearRect(0, 0, w, h)

      var bodyW = root.bodyW, bodyH = root.bodyH
      var x0 = root.bodyX, y0 = root.bodyTop, y1 = root.bodyBottom
      var r = Math.min(bodyW * 0.22, 18)
      var fg = root.foreground
      var stroke = Qt.rgba(fg.r, fg.g, fg.b, 0.9)
      var lineW = root.lineW

      function bodyPath() {
        ctx.beginPath()
        ctx.moveTo(x0, y0)
        ctx.lineTo(x0 + bodyW, y0)
        ctx.lineTo(x0 + bodyW, y1 - r)
        ctx.quadraticCurveTo(x0 + bodyW, y1, x0 + bodyW - r, y1)
        ctx.lineTo(x0 + r, y1)
        ctx.quadraticCurveTo(x0, y1, x0, y1 - r)
        ctx.closePath()
      }

      // Liquid, clipped to the cup body.
      var lvl = root.shownLevel
      if (lvl > 0.005) {
        ctx.save()
        bodyPath()
        ctx.clip()
        var top = y1 - lineW - (bodyH - lineW * 2) * lvl
        var wave = Math.max(1.5, bodyW * 0.02)
        ctx.beginPath()
        ctx.moveTo(x0, y1)
        ctx.lineTo(x0, top)
        for (var px = x0; px <= x0 + bodyW; px += 4) {
          var t = (px - x0) / bodyW
          ctx.lineTo(px, top + Math.sin(t * Math.PI * 2 + root.phase) * wave)
        }
        ctx.lineTo(x0 + bodyW, y1)
        ctx.closePath()
        var grad = ctx.createLinearGradient(0, top, 0, y1)
        grad.addColorStop(0, root.liquid)
        grad.addColorStop(1, root.liquidDeep)
        ctx.fillStyle = grad
        ctx.fill()

        // Crema line.
        ctx.beginPath()
        for (var cx = x0; cx <= x0 + bodyW; cx += 4) {
          var ct = (cx - x0) / bodyW
          var cy = top + Math.sin(ct * Math.PI * 2 + root.phase) * wave
          if (cx === x0) ctx.moveTo(cx, cy)
          else ctx.lineTo(cx, cy)
        }
        ctx.strokeStyle = root.crema
        ctx.lineWidth = Math.max(2, lineW * 1.1)
        ctx.stroke()
        ctx.restore()
      }

      // Cup outline.
      bodyPath()
      ctx.strokeStyle = stroke
      ctx.lineWidth = lineW
      ctx.lineJoin = "round"
      ctx.stroke()

      // Handle.
      var hx = x0 + bodyW
      var hy = y0 + bodyH * 0.22
      var hh = bodyH * 0.42
      var hw = bodyW * 0.28
      ctx.beginPath()
      ctx.moveTo(hx, hy)
      ctx.bezierCurveTo(hx + hw * 1.4, hy, hx + hw * 1.4, hy + hh, hx, hy + hh)
      ctx.stroke()

      // Saucer.
      ctx.beginPath()
      ctx.moveTo(x0 - bodyW * 0.12, y1 + lineW * 1.6)
      ctx.lineTo(x0 + bodyW * 1.12, y1 + lineW * 1.6)
      ctx.lineCap = "round"
      ctx.stroke()

      // Steam: three wisps, drifting with the phase.
      if (root.steaming) {
        ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.45)
        ctx.lineWidth = Math.max(1.5, lineW * 0.8)
        var baseY = y0 - lineW * 2
        var wispH = Math.max(14, bodyH * 0.32)
        for (var i = 0; i < 3; i++) {
          var sx = x0 + bodyW * (0.28 + i * 0.22)
          var drift = Math.sin(root.phase + i * 1.3) * bodyW * 0.03
          ctx.beginPath()
          ctx.moveTo(sx, baseY)
          ctx.bezierCurveTo(sx - bodyW * 0.08 + drift, baseY - wispH * 0.35,
            sx + bodyW * 0.08 + drift, baseY - wispH * 0.65,
            sx + drift * 0.5, baseY - wispH)
          ctx.stroke()
        }
      }
    }
  }

  // Label centred on the cup body, not on the whole item.
  Column {
    x: root.bodyX + root.bodyW / 2 - width / 2
    y: root.bodyTop + root.bodyH / 2 - height / 2
    spacing: Style.space(2)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      color: root.shownLevel > 0.45 ? "#f3e6d6" : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.displayLarge
      font.bold: true
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, root.shownLevel > 0.45 ? 0.35 : 0)
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.sublabel !== ""
      text: root.sublabel
      color: root.shownLevel > 0.3 ? "#f3e6d6" : Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      opacity: 0.9
    }
  }
}
