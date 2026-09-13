import QtQuick
import qs.Commons
import "Model.js" as Model

// Pixel timeline of caffeine in the body: what today's drinks did so far
// (solid cells), what the half-life predicts from now on (dim cells), the
// bedtime limit as a dashed line and bedtime itself as a marker. Every
// colour comes from the theme.
Item {
  id: root

  property var drinks: []
  property date now: new Date()
  property date bedtime: new Date()
  property real halfLife: 5
  property int bedtimeLimit: 100
  property color foreground: Color.foreground
  property color accent: Color.accent
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family
  property string timeFormat: ""

  // New cells fade in when the drink list changes.
  property var previousLevels: null
  property var lastLevels: null
  property real reveal: 1

  readonly property int cell: Math.max(3, Style.space(4))
  readonly property int gap: 1
  readonly property real axisLeft: Style.space(34)
  readonly property real axisBottom: Style.space(22)
  readonly property color dim: Qt.darker(foreground, 1.4)

  // Window: an hour before the first drink today (or 07:00), through two
  // hours past bedtime. Always at least twelve hours wide.
  readonly property var window: {
    var start = Model.startOfDay(now)
    var today = Model.todaysDrinks(drinks, now)
    var from = today.length
      ? new Date(Model.drinkTime(today[0]).getTime() - 3600000)
      : new Date(start.getTime() + 7 * 3600000)
    from = new Date(Math.min(from.getTime(), now.getTime()))
    from.setMinutes(0, 0, 0)
    var to = new Date(Math.max(bedtime.getTime() + 2 * 3600000, now.getTime() + 3 * 3600000))
    if (to.getTime() - from.getTime() < 12 * 3600000)
      to = new Date(from.getTime() + 12 * 3600000)
    return { from: from, to: to }
  }

  // The log is replaced twice per change (memory, then the file watcher), so
  // only a real difference in drinks starts the fade.
  property string drinkKey: ""
  function keyFor(list) {
    var parts = []
    for (var i = 0; i < (list || []).length; i++) parts.push(list[i].t + "|" + list[i].mg)
    return parts.join(",")
  }
  onDrinksChanged: {
    var key = keyFor(drinks)
    if (key === drinkKey) return
    var firstLoad = drinkKey === ""
    drinkKey = key
    if (firstLoad || !lastLevels) {
      canvas.requestPaint()
      return
    }
    previousLevels = lastLevels
    reveal = 0
    revealAnimation.restart()
  }
  onRevealChanged: canvas.requestPaint()

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "reveal"
    from: 0
    to: 1
    duration: 900
    easing.type: Easing.InOutSine
  }
  onNowChanged: canvas.requestPaint()
  onBedtimeChanged: canvas.requestPaint()
  onHalfLifeChanged: canvas.requestPaint()
  onBedtimeLimitChanged: canvas.requestPaint()
  onForegroundChanged: canvas.requestPaint()
  onAccentChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onVisibleChanged: if (visible) canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var from = root.window.from.getTime()
      var to = root.window.to.getTime()
      var span = Math.max(1, to - from)
      var plotX = root.axisLeft
      var plotW = width - plotX
      var plotH = height - root.axisBottom
      var pitch = root.cell + root.gap
      var columns = Math.max(1, Math.floor(plotW / pitch))
      var rows = Math.max(1, Math.floor(plotH / pitch))
      var stepMs = span / columns

      // Sample the model once per column.
      var levels = []
      var peak = root.bedtimeLimit * 1.4
      for (var c = 0; c < columns; c++) {
        var t = new Date(from + (c + 0.5) * stepMs)
        var mg = Model.inBody(root.drinks, t, root.halfLife)
        levels.push(mg)
        if (mg > peak) peak = mg
      }
      var scaleMax = Math.max(100, Math.ceil(peak / 50) * 50)

      var fg = root.foreground, ac = root.accent, ur = root.urgent
      var nowT = root.now.getTime()
      var bedT = root.bedtime.getTime()

      // Cells. Cells that were not lit before the last change fade in.
      var prev = root.previousLevels && root.previousLevels.length === columns
        ? root.previousLevels : null
      var reveal = root.reveal
      for (var i = 0; i < columns; i++) {
        var colT = from + (i + 0.5) * stepMs
        var lit = Math.round(levels[i] / scaleMax * rows)
        var litBefore = prev ? Math.round(prev[i] / scaleMax * rows) : lit
        var past = colT <= nowT
        var x = plotX + i * pitch
        for (var r = 0; r < rows; r++) {
          var y = plotH - (r + 1) * pitch + root.gap
          var on = r < lit
          var wasOn = r < litBefore
          // Resting grid first; lit cells paint over it.
          ctx.fillStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.05)
          ctx.fillRect(x, y, root.cell, root.cell)
          if (on || (wasOn && reveal < 1)) {
            var alpha = past ? 1 : 0.38
            if (on && !wasOn) alpha *= reveal          // new: fade in
            else if (!on && wasOn) alpha *= 1 - reveal  // removed: fade out
            ctx.fillStyle = Qt.rgba(ac.r, ac.g, ac.b, alpha)
            ctx.fillRect(x, y, root.cell, root.cell)
          }
        }
      }
      if (reveal >= 1) root.lastLevels = levels

      // Bedtime limit: dashed line.
      var limitY = plotH - Math.round(root.bedtimeLimit / scaleMax * rows) * pitch
      if (limitY > 0 && limitY < plotH) {
        ctx.strokeStyle = Qt.rgba(ur.r, ur.g, ur.b, 0.8)
        ctx.lineWidth = 1
        ctx.setLineDash([4, 4])
        ctx.beginPath()
        ctx.moveTo(plotX, limitY + 0.5)
        ctx.lineTo(width, limitY + 0.5)
        ctx.stroke()
        ctx.setLineDash([])
      }

      // Vertical markers: now (accent) and bedtime (foreground).
      function vline(tt, color, label) {
        if (tt < from || tt > to) return
        var vx = plotX + Math.round((tt - from) / span * plotW) + 0.5
        ctx.strokeStyle = color
        ctx.lineWidth = 1
        ctx.setLineDash([2, 3])
        ctx.beginPath()
        ctx.moveTo(vx, 0)
        ctx.lineTo(vx, plotH)
        ctx.stroke()
        ctx.setLineDash([])
        ctx.fillStyle = color
        ctx.font = "bold " + Style.font.caption + "px " + root.fontFamily
        ctx.textBaseline = "top"
        var tw = ctx.measureText(label).width
        var lx = vx + 4 + tw > width ? vx - tw - 4 : vx + 4
        ctx.fillText(label, lx, 2)
      }
      vline(nowT, ac, "now")
      vline(bedT, Qt.rgba(fg.r, fg.g, fg.b, 0.85), "bed " + Model.formatTime(root.bedtime, root.timeFormat))

      // Drink ticks along the baseline.
      ctx.fillStyle = fg
      for (var d = 0; d < root.drinks.length; d++) {
        var dt = Model.drinkTime(root.drinks[d])
        if (!dt) continue
        var dts = dt.getTime()
        if (dts < from || dts > to) continue
        var dx = plotX + Math.round((dts - from) / span * plotW)
        ctx.fillRect(dx - 2, plotH + 1, 4, 4)
      }

      // Axes: mg on the left, hours along the bottom.
      ctx.fillStyle = root.dim
      ctx.font = Style.font.caption + "px " + root.fontFamily
      ctx.textBaseline = "top"
      ctx.fillText(scaleMax + " mg", 0, 0)
      ctx.textBaseline = "bottom"
      ctx.fillText("0", 0, plotH)
      ctx.textBaseline = "top"
      var hours = Math.round(span / 3600000)
      var every = hours > 18 ? 6 : (hours > 10 ? 3 : 2)
      var first = new Date(from)
      first.setMinutes(0, 0, 0)
      for (var ht = first.getTime(); ht <= to; ht += 3600000) {
        var hd = new Date(ht)
        if (hd.getHours() % every !== 0) continue
        var hx = plotX + (ht - from) / span * plotW
        if (hx < plotX) continue
        var hl = Model.formatTime(hd, root.timeFormat)
        var hw = ctx.measureText(hl).width
        if (hx + hw > width) continue
        ctx.fillText(hl, hx, plotH + 7)
      }
    }
  }
}
