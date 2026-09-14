import QtQuick
import qs.Commons

// The hero: a mug that fills with coffee exactly as far as today's caffeine
// is towards the daily limit. Outline and label follow the theme; the
// liquid stays coffee-brown because some things are sacred. Empty at 0 %.
//
// Logging pours: a stream falls into the cup, the surface swells and
// settles, the number counts up. Past the limit it is a stack overflow: the
// crema turns the theme's urgent colour, the surface boils, drips run down
// the outside and the steam turns to smoke.
Item {
  id: root

  property real level: 0            // 0..1+ of the daily limit
  property color foreground: Color.foreground
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family
  property string label: ""
  property string sublabel: ""
  // Off for the small week cups: the steam stands still and no timer runs.
  property bool animated: true
  // The owner's "is on screen" signal: a hidden popup keeps Item.visible
  // true, so the panel passes its opened state here to stop the ticking.
  property bool active: true

  readonly property bool overLimit: level > 1
  readonly property bool empty: shownLevel <= 0.005
  readonly property bool steaming: !empty
  readonly property color liquid: "#6b4630"
  readonly property color liquidDeep: "#3a2416"
  readonly property color crema: "#c99d6c"
  readonly property color cremaLight: "#ebd0a8"

  // Geometry shared by the canvas and the centred label. The cup tapers a
  // little towards the bottom and sits left of centre so the handle has
  // room on the right.
  readonly property real bodyW: Math.min(width * 0.6, height * 0.6)
  readonly property real bodyH: bodyW * 1.02
  readonly property real taper: bodyW * 0.07
  readonly property real bodyX: (width - bodyW) / 2 - bodyW * 0.1
  readonly property real bodyBottom: height - Math.max(8, height * 0.09)
  readonly property real bodyTop: bodyBottom - bodyH
  readonly property real lineW: Math.max(2, bodyW * 0.032)

  // The unclamped value glides towards `level`; the clamped copy drives the
  // liquid. Owners can show Math.round(shownValue * 100) to get a counting
  // percentage. Animation is switched on after the first frame so opening
  // the panel does not pour the whole day in.
  property real shownValue: level
  readonly property real shownLevel: Math.max(0, Math.min(1, shownValue))
  property bool animate: false
  property real lastLevel: level

  // Motion state: `phase` runs continuously, `splash` spikes on a change
  // and settles, `pour` is the stream's opacity while the level rises.
  property real phase: 0
  property real splash: 0
  property real pour: 0

  Behavior on shownValue {
    enabled: root.animate && root.animated && root.active
    NumberAnimation { duration: 1100; easing.type: Easing.OutCubic }
  }
  Component.onCompleted: Qt.callLater(function() { root.animate = true })

  // A mode switch (today's intake <-> in your system) is not a new cup: the
  // liquid glides and sloshes, but nothing pours and the label crossfades.
  property bool switching: false
  function flip() {
    switching = true
    labelFade.restart()
    switchGuard.restart()
  }
  Timer { id: switchGuard; interval: 600; onTriggered: root.switching = false }

  onLevelChanged: {
    if (animate && animated && active && Math.abs(level - lastLevel) > 0.002) {
      splashAnimation.restart()
      if (level > lastLevel && !switching) pourAnimation.restart()
    }
    lastLevel = level
  }
  onShownValueChanged: canvas.requestPaint()
  onSplashChanged: canvas.requestPaint()
  onPourChanged: canvas.requestPaint()
  onForegroundChanged: canvas.requestPaint()
  onUrgentChanged: canvas.requestPaint()
  onOverLimitChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  SequentialAnimation {
    id: splashAnimation
    NumberAnimation { target: root; property: "splash"; to: 1; duration: 180; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "splash"; to: 0; duration: 1400; easing.type: Easing.OutQuint }
  }
  SequentialAnimation {
    id: pourAnimation
    NumberAnimation { target: root; property: "pour"; to: 1; duration: 140; easing.type: Easing.OutQuad }
    PauseAnimation { duration: 520 }
    NumberAnimation { target: root; property: "pour"; to: 0; duration: 380; easing.type: Easing.InQuad }
  }

  // 30 fps is plenty for steam and a slow swell; the frame rate matters
  // less than the easing between frames.
  Timer {
    interval: 33
    running: root.visible && root.active && root.steaming && root.animated
    repeat: true
    onTriggered: {
      root.phase = (root.phase + (root.overLimit ? 0.13 : 0.035)) % (Math.PI * 200)
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

      var bodyW = root.bodyW, bodyH = root.bodyH, taper = root.taper
      var x0 = root.bodyX, y0 = root.bodyTop, y1 = root.bodyBottom
      var xl = x0 + taper, xr = x0 + bodyW - taper      // bottom corners
      var r = Math.min(bodyW * 0.2, 16)
      var fg = root.foreground, ur = root.urgent
      var lineW = root.lineW
      var angry = root.overLimit
      var ph = root.phase
      var splash = root.splash

      // Smooth "boil" instead of random jitter: two incommensurate sines.
      var boil = angry ? Math.sin(ph * 9.1) * 0.5 + Math.sin(ph * 13.7) * 0.5 : 0

      ctx.save()
      if (angry) ctx.translate(boil * 1.2, 0)

      function bodyPath(inset) {
        var i = inset || 0
        ctx.beginPath()
        ctx.moveTo(x0 + i, y0 + i)
        ctx.lineTo(x0 + bodyW - i, y0 + i)
        ctx.lineTo(xr - i, y1 - r - i)
        ctx.quadraticCurveTo(xr - i, y1 - i, xr - r - i, y1 - i)
        ctx.lineTo(xl + r + i, y1 - i)
        ctx.quadraticCurveTo(xl + i, y1 - i, xl + i, y1 - r - i)
        ctx.closePath()
      }

      // Surface height at horizontal fraction t (0..1). A slow long wave
      // plus a faster ripple; the splash raises both for a moment.
      var inner = bodyH - lineW * 2
      var lvl = root.shownLevel
      var top = y1 - lineW - inner * lvl
      if (angry) top = Math.min(top, y0 + lineW * 0.2)
      var a1 = bodyW * (angry ? 0.035 : 0.009) + splash * bodyW * 0.045
      var a2 = a1 * (angry ? 0.9 : 0.45)
      function surface(t) {
        var y = top + Math.sin(t * Math.PI * 2 + ph) * a1
          + Math.sin(t * Math.PI * 4.6 - ph * 1.7 + splash * 6) * a2
        if (angry) y += Math.sin(t * 19 + ph * 2.3) * a1 * 0.5 + boil * 1.5
        return y
      }
      function surfacePath(closeToBottom) {
        ctx.beginPath()
        for (var px = x0; px <= x0 + bodyW + 0.5; px += 2) {
          var t = (px - x0) / bodyW
          if (px === x0) ctx.moveTo(px, surface(t))
          else ctx.lineTo(Math.min(px, x0 + bodyW), surface(t))
        }
        if (closeToBottom) {
          ctx.lineTo(x0 + bodyW, y1 + 2)
          ctx.lineTo(x0, y1 + 2)
          ctx.closePath()
        }
      }

      // Drop shadow on the saucer, before anything else.
      ctx.beginPath()
      ctx.ellipse(x0 + bodyW * 0.08, y1 - lineW * 0.6, bodyW * 0.84, lineW * 3.2)
      ctx.fillStyle = Qt.rgba(0, 0, 0, 0.22)
      ctx.fill()

      // ---- liquid, clipped to the cup ----
      if (lvl > 0.005 || angry) {
        ctx.save()
        bodyPath(lineW * 0.5)
        ctx.clip()

        surfacePath(true)
        var grad = ctx.createLinearGradient(0, top, 0, y1)
        grad.addColorStop(0, root.liquid)
        grad.addColorStop(1, root.liquidDeep)
        ctx.fillStyle = grad
        ctx.fill()

        // Wall shading: darker towards both walls, so the cup reads round.
        var walls = ctx.createLinearGradient(x0, 0, x0 + bodyW, 0)
        walls.addColorStop(0, Qt.rgba(0, 0, 0, 0.28))
        walls.addColorStop(0.18, Qt.rgba(0, 0, 0, 0))
        walls.addColorStop(0.8, Qt.rgba(0, 0, 0, 0))
        walls.addColorStop(1, Qt.rgba(0, 0, 0, 0.32))
        ctx.fillStyle = walls
        surfacePath(true)
        ctx.fill()

        // A soft light falling from the upper left.
        var sheen = ctx.createLinearGradient(x0 + bodyW * 0.1, 0, x0 + bodyW * 0.45, 0)
        sheen.addColorStop(0, Qt.rgba(1, 1, 1, 0))
        sheen.addColorStop(0.5, Qt.rgba(1, 1, 1, 0.09))
        sheen.addColorStop(1, Qt.rgba(1, 1, 1, 0))
        ctx.fillStyle = sheen
        ctx.fillRect(x0 + bodyW * 0.1, top + lineW * 2, bodyW * 0.35, y1 - top)

        // Inner shadow just under the surface: the liquid has depth.
        var under = ctx.createLinearGradient(0, top, 0, top + lineW * 4)
        under.addColorStop(0, Qt.rgba(0, 0, 0, 0.3))
        under.addColorStop(1, Qt.rgba(0, 0, 0, 0))
        ctx.fillStyle = under
        surfacePath(true)
        ctx.fill()

        // Crema: a band that fades into the coffee, with a bright edge.
        var bandH = Math.max(3, lineW * 1.8)
        ctx.beginPath()
        for (var cx = x0; cx <= x0 + bodyW + 0.5; cx += 2) {
          var ct = (cx - x0) / bodyW
          var cy = surface(ct)
          if (cx === x0) ctx.moveTo(cx, cy)
          else ctx.lineTo(Math.min(cx, x0 + bodyW), cy)
        }
        for (var bx = x0 + bodyW; bx >= x0 - 0.5; bx -= 2) {
          var bt = Math.max(0, bx - x0) / bodyW
          ctx.lineTo(Math.max(bx, x0), surface(bt) + bandH)
        }
        ctx.closePath()
        var band = ctx.createLinearGradient(0, top - a1, 0, top + bandH + a1)
        if (angry) {
          band.addColorStop(0, Qt.rgba(ur.r, ur.g, ur.b, 0.95))
          band.addColorStop(1, Qt.rgba(ur.r, ur.g, ur.b, 0.15))
        } else {
          band.addColorStop(0, root.crema)
          band.addColorStop(1, Qt.rgba(0.79, 0.62, 0.42, 0.1))
        }
        ctx.fillStyle = band
        ctx.fill()

        surfacePath(false)
        ctx.strokeStyle = angry
          ? Qt.rgba(1, 1, 1, 0.55 + Math.abs(boil) * 0.3)
          : root.cremaLight
        ctx.lineWidth = Math.max(1.2, lineW * 0.55)
        ctx.lineJoin = "round"
        ctx.stroke()

        // Bubbles in the crema: a few slow, tiny circles drifting sideways.
        var bubbleCount = angry ? 6 : 3
        ctx.strokeStyle = angry ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.22)
        ctx.lineWidth = 0.8
        for (var b = 0; b < bubbleCount; b++) {
          var bt2 = ((b * 0.37 + 0.15 + ph * 0.01 * (b % 2 ? 1 : -1)) % 1 + 1) % 1
          var bxp = x0 + bodyW * bt2
          var byp = surface(bt2) + bandH * 0.55
          var brad = 0.7 + ((b * 7) % 3) * 0.35
          ctx.beginPath()
          ctx.arc(bxp, byp, brad, 0, Math.PI * 2)
          ctx.stroke()
        }
        ctx.restore()
      }

      // ---- the pour: a stream from above, only while the level rises ----
      if (root.pour > 0.01 && !angry) {
        var sx0 = x0 + bodyW * 0.5
        var wobble = Math.sin(ph * 3) * lineW * 0.15
        var streamTop = Math.max(0, y0 - bodyH * 0.55)
        var streamBottom = surface(0.5) + lineW
        var stream = ctx.createLinearGradient(0, streamTop, 0, streamBottom)
        stream.addColorStop(0, Qt.rgba(0.42, 0.27, 0.19, 0))
        stream.addColorStop(0.35, Qt.rgba(0.42, 0.27, 0.19, root.pour))
        stream.addColorStop(1, Qt.rgba(0.42, 0.27, 0.19, root.pour))
        ctx.strokeStyle = stream
        ctx.lineWidth = lineW * 1.15
        ctx.lineCap = "round"
        ctx.beginPath()
        ctx.moveTo(sx0 + wobble, streamTop)
        ctx.quadraticCurveTo(sx0 - wobble, (streamTop + streamBottom) / 2, sx0, streamBottom)
        ctx.stroke()
        // Splash droplets either side of the impact.
        ctx.fillStyle = Qt.rgba(0.79, 0.62, 0.42, root.pour * 0.8)
        for (var d = -1; d <= 1; d += 2) {
          var dx = sx0 + d * (lineW * 2 + splash * lineW * 3)
          var dy = surface(0.5) - splash * lineW * 2.5
          ctx.beginPath()
          ctx.arc(dx, dy, Math.max(0.8, lineW * 0.35), 0, Math.PI * 2)
          ctx.fill()
        }
      }

      // ---- overflow: drips running down the outside of both walls ----
      if (angry) {
        ctx.strokeStyle = root.crema
        ctx.fillStyle = root.crema
        ctx.lineCap = "round"
        ctx.lineWidth = lineW * 0.75
        for (var k = 0; k < 2; k++) {
          var side = k === 0 ? -1 : 1
          var dripLen = bodyH * (0.22 + 0.14 * (0.5 + 0.5 * Math.sin(ph * 0.9 + k * 2.1)))
          var wallX = function(y) {   // the slanted wall at height y, just outside it
            var f = (y - y0) / bodyH
            return (side < 0 ? x0 + taper * f : x0 + bodyW - taper * f) + side * lineW * 0.9
          }
          ctx.beginPath()
          ctx.moveTo(wallX(y0), y0 + lineW * 0.5)
          ctx.lineTo(wallX(y0 + dripLen), y0 + dripLen)
          ctx.stroke()
          ctx.beginPath()
          ctx.arc(wallX(y0 + dripLen), y0 + dripLen, lineW * 0.6, 0, Math.PI * 2)
          ctx.fill()
        }
      }

      // ---- cup outline, rim, handle, saucer ----
      var stroke = Qt.rgba(fg.r, fg.g, fg.b, 0.92)
      bodyPath(0)
      ctx.strokeStyle = stroke
      ctx.lineWidth = lineW
      ctx.lineJoin = "round"
      ctx.stroke()

      // Rim thickness: a fainter inner line just below the top edge.
      ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.28)
      ctx.lineWidth = Math.max(1, lineW * 0.5)
      ctx.beginPath()
      ctx.moveTo(x0 + lineW, y0 + lineW * 1.4)
      ctx.lineTo(x0 + bodyW - lineW, y0 + lineW * 1.4)
      ctx.stroke()

      // A highlight down the left wall, like glazed ceramic.
      ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.18)
      ctx.lineWidth = Math.max(1, lineW * 0.45)
      ctx.beginPath()
      ctx.moveTo(x0 + lineW * 1.6, y0 + bodyH * 0.12)
      ctx.lineTo(x0 + taper * 0.85 + lineW * 1.6, y1 - r - lineW)
      ctx.stroke()

      // Handle: one clean D, a touch heavier than the body line.
      var hx = x0 + bodyW - lineW * 0.4
      var hy = y0 + bodyH * 0.2
      var hh = bodyH * 0.44
      var hw = bodyW * 0.3
      ctx.strokeStyle = stroke
      ctx.lineWidth = lineW * 1.15
      ctx.lineCap = "round"
      ctx.beginPath()
      ctx.moveTo(hx, hy)
      ctx.bezierCurveTo(hx + hw * 1.5, hy - hh * 0.04, hx + hw * 1.5, hy + hh * 1.04, hx, hy + hh)
      ctx.stroke()

      // Saucer: a shallow ellipse behind the foot, front edge drawn solid.
      var scx = x0 + bodyW / 2
      var sry = lineW * 1.5
      var srx = bodyW * 0.64
      ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.35)
      ctx.lineWidth = Math.max(1, lineW * 0.5)
      ctx.beginPath()
      ctx.ellipse(scx - srx, y1 + lineW * 0.6 - sry, srx * 2, sry * 2)
      ctx.stroke()
      ctx.strokeStyle = stroke
      ctx.lineWidth = lineW
      ctx.beginPath()
      ctx.moveTo(scx - srx, y1 + lineW * 0.6)
      ctx.bezierCurveTo(scx - srx * 0.7, y1 + lineW * 0.6 + sry * 2.2,
        scx + srx * 0.7, y1 + lineW * 0.6 + sry * 2.2, scx + srx, y1 + lineW * 0.6)
      ctx.stroke()

      // ---- steam: soft wisps that fade out as they rise ----
      if (root.steaming) {
        var baseY = y0 - lineW * 1.5
        var wispH = Math.max(16, bodyH * (angry ? 0.5 : 0.36))
        var count = angry ? 5 : 3
        var tint = angry ? ur : fg
        for (var i = 0; i < count; i++) {
          var breathe = 0.86 + 0.14 * Math.sin(ph * 0.8 + i * 1.9)
          var sx = x0 + bodyW * (angry ? 0.15 + i * 0.175 : 0.26 + i * 0.24)
          var drift = Math.sin(ph * 0.9 + i * 1.3) * bodyW * (angry ? 0.08 : 0.035)
          var sway = Math.cos(ph * 0.6 + i * 0.7) * bodyW * 0.03
          var hgt = wispH * breathe
          var alpha = angry ? 0.5 : 0.42
          var wisp = ctx.createLinearGradient(0, baseY, 0, baseY - hgt)
          wisp.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, 0))
          wisp.addColorStop(0.2, Qt.rgba(tint.r, tint.g, tint.b, alpha))
          wisp.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, 0))
          ctx.strokeStyle = wisp
          ctx.lineCap = "round"
          // Two passes: a wide faint one for softness, a thin one for shape.
          for (var pass = 0; pass < 2; pass++) {
            ctx.lineWidth = pass === 0 ? Math.max(3, lineW * 1.6) : Math.max(1.2, lineW * 0.7)
            ctx.globalAlpha = pass === 0 ? 0.35 : 1
            ctx.beginPath()
            ctx.moveTo(sx, baseY)
            ctx.bezierCurveTo(sx - bodyW * 0.09 + drift + sway, baseY - hgt * 0.35,
              sx + bodyW * 0.09 + drift - sway, baseY - hgt * 0.68,
              sx + drift * 0.6, baseY - hgt)
            ctx.stroke()
          }
          ctx.globalAlpha = 1
        }
      }

      ctx.restore()
    }
  }

  SequentialAnimation {
    id: labelFade
    NumberAnimation { target: labelColumn; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InQuad }
    NumberAnimation { target: labelColumn; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
  }

  // Label centred on the cup body, hidden while the cup is empty.
  Column {
    id: labelColumn
    visible: !root.empty
    x: root.bodyX + root.bodyW / 2 - width / 2
    y: root.bodyTop + root.bodyH / 2 - height / 2
    spacing: Style.space(2)

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.label
      color: root.overLimit ? root.urgent : (root.shownLevel > 0.45 ? "#f3e6d6" : root.foreground)
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
      color: root.overLimit ? root.urgent : (root.shownLevel > 0.3 ? "#f3e6d6" : Qt.darker(root.foreground, 1.4))
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: root.overLimit
      opacity: 0.95
    }
  }
}
