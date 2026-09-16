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
  property color background: Color.background
  property color accent: Color.accent
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family
  property string timeFormat: ""

  // Hovering shows the time under the pointer and the level in the body at
  // that time, past or future, so the forecast can be read off the graph.
  // Backdating: a click emits `picked` with that time (snapped to five
  // minutes) but only up to now; clicks in the future emit null. `pickTime`
  // is the time the owner is currently logging at, drawn as a marker until
  // it is cleared.
  property bool pickable: true
  property var pickTime: null
  property var hoverTime: null
  signal picked(var time)

  // Time under x anywhere in the window, snapped to five minutes.
  function hoverAt(x) {
    var from = window.from.getTime(), to = window.to.getTime()
    var plotW = width - axisLeft
    if (plotW <= 0 || x < axisLeft || x > width) return null
    var t = from + (x - axisLeft) / plotW * (to - from)
    var step = 5 * 60000
    return new Date(Math.min(to, Math.round(t / step) * step))
  }

  // Time under x for logging: null in the future.
  function timeAt(x) {
    var t = hoverAt(x)
    if (!t || t.getTime() > now.getTime()) return null
    return Model.snapTime(t, now, 5)
  }

  // New cells fade in when the drink list changes.
  property var previousLevels: null
  property var lastLevels: null
  property real reveal: 1

  readonly property int cell: Math.max(3, Style.space(4))
  readonly property int gap: 1
  readonly property real axisLeft: Style.space(34)
  readonly property real axisBottom: Style.space(22)
  readonly property color dim: Qt.darker(foreground, 1.4)

  // Window: from 06:00 (earlier if a drink was earlier) through two hours
  // past bedtime, always at least twelve hours wide. Starting at 06:00 keeps
  // the whole morning clickable for backdating.
  readonly property var window: {
    var start = Model.startOfDay(now)
    var today = Model.todaysDrinks(drinks, now)
    var from = new Date(start.getFullYear(), start.getMonth(), start.getDate(), 6)
    if (today.length)
      from = new Date(Math.min(from.getTime(), Model.drinkTime(today[0]).getTime() - 3600000))
    from = new Date(Math.min(from.getTime(), now.getTime()))
    from.setMinutes(0, 0, 0)
    var to = new Date(Math.max(bedtime.getTime() + 2 * 3600000, now.getTime() + 3 * 3600000))
    if (to.getTime() - from.getTime() < 12 * 3600000)
      to = new Date(from.getTime() + 12 * 3600000)
    return { from: from, to: to }
  }

  // The log is replaced twice per change (memory, then the file watcher), so
  // only a real difference in drinks starts the fade. When the change also
  // moves the window, old and new columns are different times, so no fade.
  property string drinkKey: "unset"
  property string windowKey: ""
  function keyFor(list) {
    var parts = []
    for (var i = 0; i < (list || []).length; i++) parts.push(list[i].t + "|" + list[i].mg)
    return parts.join(",")
  }
  onDrinksChanged: {
    var key = keyFor(drinks)
    if (key === drinkKey) return
    var firstLoad = drinkKey === "unset"
    drinkKey = key
    var newWindowKey = window.from.getTime() + "-" + window.to.getTime()
    var moved = newWindowKey !== windowKey
    windowKey = newWindowKey
    sampleKey = ""
    if (firstLoad || moved || !lastLevels) {
      canvas.requestPaint()
      return
    }
    previousLevels = lastLevels
    reveal = 0
    revealAnimation.restart()
  }

  // Sampling the model per column is the expensive part of a repaint, and
  // hovering repaints often; cache the samples until something they depend
  // on changes.
  property string sampleKey: ""
  property var sampleLevels: []
  function samples(from, span, columns, stepMs) {
    var key = drinkKey + "|" + from + "|" + span + "|" + columns + "|" + halfLife
    if (key === sampleKey) return sampleLevels
    var levels = []
    for (var c = 0; c < columns; c++)
      levels.push(Model.inBody(drinks, new Date(from + (c + 0.5) * stepMs), halfLife))
    sampleKey = key
    sampleLevels = levels
    return levels
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
  onBackgroundChanged: canvas.requestPaint()
  onAccentChanged: canvas.requestPaint()
  onUrgentChanged: canvas.requestPaint()
  onFontFamilyChanged: canvas.requestPaint()
  onTimeFormatChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()
  onVisibleChanged: if (visible) canvas.requestPaint()
  onPickTimeChanged: canvas.requestPaint()
  onHoverTimeChanged: canvas.requestPaint()

  MouseArea {
    anchors.fill: parent
    enabled: root.pickable
    hoverEnabled: true
    cursorShape: root.hoverTime && root.hoverTime.getTime() <= root.now.getTime()
      ? Qt.PointingHandCursor : Qt.ArrowCursor
    onPositionChanged: function(mouse) {
      var t = root.hoverAt(mouse.x)
      var same = (t === null && root.hoverTime === null)
        || (t !== null && root.hoverTime !== null && t.getTime() === root.hoverTime.getTime())
      if (!same) root.hoverTime = t
    }
    onExited: root.hoverTime = null
    onClicked: function(mouse) { root.picked(root.timeAt(mouse.x)) }
  }

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

      // One sample per column, cached across hover repaints.
      var levels = root.samples(from, span, columns, stepMs)
      var peak = root.bedtimeLimit * 1.4
      for (var c = 0; c < columns; c++) if (levels[c] > peak) peak = levels[c]
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

      // Markers: the pointer's time and level (dim) and the picked time
      // (accent, solid). The label rides just above the lit cells under it
      // so it is never hidden behind the curve, and stays below the "now"
      // and bedtime labels along the top.
      function marker(date, color, solid) {
        if (!date) return
        var tt = date.getTime()
        if (tt < from || tt > to) return
        var mx = plotX + Math.round((tt - from) / span * plotW) + 0.5
        ctx.strokeStyle = color
        ctx.lineWidth = solid ? 2 : 1
        ctx.setLineDash(solid ? [] : [1, 3])
        ctx.beginPath()
        ctx.moveTo(mx, 0)
        ctx.lineTo(mx, plotH)
        ctx.stroke()
        ctx.setLineDash([])
        ctx.fillStyle = color
        ctx.font = (solid ? "bold " : "") + Style.font.caption + "px " + root.fontFamily
        ctx.textBaseline = "bottom"
        var label = solid
          ? "log at " + Model.formatTime(date, root.timeFormat)
          : Model.formatTime(date, root.timeFormat) + " · "
            + Math.round(Model.inBody(root.drinks, date, root.halfLife)) + " mg"
        var lw = ctx.measureText(label).width
        // The tallest column under the label's span decides how high it
        // sits; of the two sides of the marker, take the one with the lower
        // curve so the label stays clear of the "now" label when it can.
        function topAt(x0) {
          var c0 = Math.max(0, Math.floor((x0 - plotX) / pitch))
          var c1 = Math.min(columns - 1, Math.floor((x0 + lw - plotX) / pitch))
          var tallest = 0
          for (var lc = c0; lc <= c1; lc++) {
            var lit = Math.round(levels[lc] / scaleMax * rows)
            if (lit > tallest) tallest = lit
          }
          return plotH - tallest * pitch
        }
        var rightX = mx + 4, leftX = mx - lw - 4
        var lx = rightX, top = topAt(rightX)
        var rightFits = rightX + lw <= width, leftFits = leftX >= plotX
        if (!rightFits && leftFits) { lx = leftX; top = topAt(leftX) }
        else if (rightFits && leftFits) {
          var leftTop = topAt(leftX)
          if (leftTop > top) { lx = leftX; top = leftTop }
        }
        var minY = Style.font.caption + 8
        var ly = Math.max(minY, top - 2)
        // Forced into the top band, the label can land on the cells or the
        // "now" label; knock out a background behind it so it stays legible.
        if (top - 2 < minY) {
          var bg = root.background
          ctx.fillStyle = Qt.rgba(bg.r, bg.g, bg.b, 0.85)
          ctx.fillRect(lx - 2, ly - Style.font.caption - 2, lw + 4, Style.font.caption + 4)
          ctx.fillStyle = color
        }
        ctx.fillText(label, lx, ly)
      }
      if (root.pickTime) marker(root.pickTime, ac, true)
      else if (root.hoverTime) marker(root.hoverTime, Qt.rgba(fg.r, fg.g, fg.b, 0.7), false)

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
