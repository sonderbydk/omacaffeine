import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// OmaCaffeine panel: log a drink, watch the cup fill, and see the cut-off
// for tonight. State lives in ~/.local/state/omacaffeine/log.json, custom
// drinks and mg overrides in ~/.config/omacaffeine/drinks.json; the settings
// live inline on the bar entry in shell.json like every widget.
Panel {
  id: root
  moduleName: "io.github.sonderbydk.omacaffeine"
  ipcTarget: "io.github.sonderbydk.omacaffeine"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var shell: null
  readonly property var barIdentity: hostWidget || root

  // ---- state -------------------------------------------------------------
  property var log: Model.emptyLog()
  property var drinksConfig: Model.emptyDrinksConfig()
  // Nothing is written back until the file has been read and understood:
  // writing an empty in-memory log over a real one would erase the day, and
  // writing over a file we could not parse would destroy whatever it was.
  property bool logLoaded: false
  property bool drinksLoaded: false
  property string lastError: ""
  property date now: new Date()
  property string page: "main"          // "main" | "settings" | "week" | "drink"
  property int seed: Math.floor(Math.random() * 1000)
  property string bedtimeDraft: ""
  property string clockFormat: ""

  // The confirmation over the cup: text stays while it fades out, so the
  // layout never jumps.
  property string flash: ""
  property bool flashVisible: false

  // Backdating: a time picked on the graph, waiting for a drink.
  property var pickTime: null
  // The drink added most recently in this session, so undo removes that
  // one even when it was logged back in time.
  property var lastLogged: null

  // Output tokens per hour from the coding agents, via tokens.py.
  property var tokens: ({ hours: {}, sources: {}, skipped: 0 })
  property double tokensFetchedAt: 0
  property string tokensState: "idle"      // idle | loading | ok | failed

  // Drink editor draft.
  property var editing: null            // { kind, custom, isNew }
  property string draftName: ""
  property int draftMg: 0
  property string draftIcon: "mug"

  readonly property string stateDir: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")
  readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME")
    || (Quickshell.env("HOME") + "/.config")
  readonly property string logPath: stateDir + "/omacaffeine/log.json"
  readonly property string drinksPath: configDir + "/omacaffeine/drinks.json"
  readonly property string shellConfigPath: configDir + "/omarchy/shell.json"
  readonly property string pluginDir: String(Qt.resolvedUrl(".")).replace(/^file:\/\//, "").replace(/\/$/, "")

  // Times follow the Omarchy clock widget (24-hour unless it shows AM/PM),
  // and fall back to the system locale when no clock is configured.
  readonly property string timeFmt: Model.timeFormatFromClock(clockFormat)

  // ---- settings ----------------------------------------------------------
  readonly property int bodyWeightKg: Math.max(1, Number(setting("bodyWeightKg", 80)) || 80)
  readonly property string activity: String(setting("activity", "Sitting"))
  readonly property string bedtime: Model.normalizedBedtime(setting("bedtime", "23:00"))
  readonly property int dailyLimitMg: Math.max(1, Number(setting("dailyLimitMg", 400)) || 400)
  readonly property int bedtimeLimitMg: Math.max(0, Number(setting("bedtimeLimitMg", Model.DEFAULT_BEDTIME_LIMIT)) || 0)
  readonly property real halfLife: Model.halfLifeHours(activity)
  readonly property int recommendedDaily: Model.recommendedDailyLimit(bodyWeightKg)
  readonly property int singleDose: Model.singleDoseLimit(bodyWeightKg)
  readonly property string cupMode: String(setting("cupMode", "Today's intake"))
  readonly property string barDisplay: String(setting("barDisplay", "Icon"))
  readonly property bool imperial: Model.usesImperialWeight()
  readonly property string weightUnit: imperial ? "lb" : "kg"
  readonly property int weightShown: imperial ? Model.kgToLb(bodyWeightKg) : bodyWeightKg

  // ---- derived -----------------------------------------------------------
  readonly property var drinks: Model.allDrinks(drinksConfig)
  readonly property int gridColumns: 5
  // Presets, custom drinks, then "+ Create my own" tiles that fill the row.
  readonly property var gridModel: {
    var list = drinks.slice()
    var pad = (gridColumns - list.length % gridColumns) % gridColumns
    if (pad === 0) pad = 1
    for (var i = 0; i < pad; i++) list.push({ placeholder: true, kind: "new-" + i })
    return list
  }
  // Aggregates are keyed on the calendar day and hour rather than on `now`,
  // so the 30 s clock does not rebuild lists while the panel is closed.
  readonly property string dayKey: Model.hourKey(now).slice(0, 10)
  readonly property string hourKeyNow: Model.hourKey(now)
  readonly property date dayStart: Model.dateFromKey(dayKey)
  readonly property date hourStart: Model.dateFromKey(hourKeyNow)
  readonly property var today: Model.todaysDrinks(log.drinks, dayStart)
  readonly property int todayMg: Model.totalMg(today)
  readonly property int todayPercent: Math.round(todayMg / dailyLimitMg * 100)
  readonly property real level: todayMg / dailyLimitMg
  readonly property bool cupShowsBody: cupMode === "In your system"
  readonly property real cupLevel: cupShowsBody ? inBodyMg / dailyLimitMg : level
  readonly property bool overLimit: todayMg > dailyLimitMg
  readonly property var first: Model.firstDrink(today)
  readonly property var last: Model.lastDrink(log.drinks)
  // "Again" means the last drink you logged (even back in time); when that
  // kind no longer exists, the latest drink in the log, then espresso.
  readonly property string lastKind: {
    var candidates = [String(log.lastKind || ""), last ? String(last.kind) : "", "espresso"]
    for (var i = 0; i < candidates.length; i++)
      if (candidates[i] && Model.drink(candidates[i], drinksConfig).kind === candidates[i])
        return candidates[i]
    return "espresso"
  }
  readonly property var lastPreset: Model.drink(lastKind, drinksConfig)
  readonly property int inBodyMg: Math.round(Model.inBody(log.drinks, now, halfLife))
  readonly property var cutoff: Model.cutoff(log.drinks, now, bedtime, halfLife,
    bedtimeLimitMg, lastPreset.mg)
  readonly property var caffeineFreeAt: Model.timeUntilBelow(log.drinks, now, halfLife, 10)
  readonly property string bedtimeLabel: Model.formatTime(Model.bedtimeAsDate(bedtime, now), timeFmt)
  readonly property bool cutoffOk: cutoff.status === "clear" || cutoff.status === "until"
  readonly property string statusLine: {
    var c = cutoff
    if (c.status === "clear")
      return "Clear for bedtime · another " + lastPreset.name + " still fits"
    if (c.status === "until")
      return "Cut-off " + Model.formatTimeFrom(c.time, now, timeFmt) + " for another " + lastPreset.name
    if (c.status === "passed")
      return "Past cut-off for another " + lastPreset.name + " · decaf from here"
    return "Over the bedtime limit · under " + bedtimeLimitMg + " mg "
      + (c.time ? "by " + Model.formatTimeFrom(c.time, now, timeFmt) : "not within two days")
  }
  readonly property string firstLine: first
    ? "First caffeine today: " + Model.formatTime(Model.drinkTime(first), timeFmt)
      + " · " + first.name
    : "Let's brew you some coffee — you deserve it!"
  readonly property string gridHeading: pickTime
    ? Model.backdateHeading(seed) + " · " + Model.formatTime(pickTime, timeFmt) + " · Esc cancels"
    : Model.heading(seed)
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.4)

  // ---- week --------------------------------------------------------------
  readonly property var week: Model.dayTotals(log.drinks, dayStart, 7)
  readonly property var weekTokens: week.map(function(d) { return Model.tokensForDay(tokens.hours, d.date) })
  readonly property int weekAvgMg: Math.round(Model.mean(week.map(function(d) { return d.mg })))
  readonly property real weekAvgDrinks: Model.mean(week.map(function(d) { return d.count }))
  readonly property var weekPeak: week.reduce(function(best, d) { return !best || d.mg > best.mg ? d : best }, null)
  readonly property int weekTokenTotal: weekTokens.reduce(function(a, b) { return a + b }, 0)
  readonly property int weekTokenMax: Math.max(1, Math.max.apply(null, weekTokens))
  readonly property int weekMgTotal: week.reduce(function(a, d) { return a + d.mg }, 0)
  readonly property real mgSlope: Model.slope(week.map(function(d) { return d.mg }))
  readonly property real tokenSlope: Model.slope(weekTokens)
  readonly property var activeHours: Model.activeHours(log.drinks, tokens.hours, hourStart, 7, halfLife)
  readonly property var buckets: Model.tokenBuckets(activeHours)
  readonly property var sweetSpot: Model.sweetSpot(buckets)
  readonly property real bucketMax: Math.max(1, Math.max.apply(null, buckets.map(function(b) { return b.perHour })))
  readonly property real hourR: Model.pearson(activeHours.map(function(p) { return p.mg }),
    activeHours.map(function(p) { return p.tokens }))
  readonly property int sourceFiles: tokens.sources
    ? (Number(tokens.sources.claude) || 0) + (Number(tokens.sources.codex) || 0) : 0

  // ---- lifecycle ---------------------------------------------------------
  function open() {
    setCenterHoverRevealSuppressed(false)
    refresh()
    root.controller.show()
  }

  function openFromHotkey() {
    refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    page = "main"
    pickTime = null
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function goBack() {
    if (pickTime) {
      pickTime = null
      return true
    }
    if (page !== "main") {
      page = "main"
      return true
    }
    return false
  }

  function showPage(name) {
    page = name
    if (name === "week") fetchTokens(false)
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    now = new Date()
    seed = Math.floor(Math.random() * 1000)
    logFile.reload()
    drinksFile.reload()
    shellConfigFile.reload()
    if (page === "week") fetchTokens(false)
  }

  // The scan is cheap but not free; only the week page needs it, and a
  // successful scan is good for two minutes.
  function fetchTokens(force) {
    if (!force && tokensState === "ok" && Date.now() - tokensFetchedAt < 120000) return
    if (tokensProcess.running) return
    tokensState = "loading"
    tokensProcess.running = true
  }

  // ---- log ---------------------------------------------------------------
  // Logs `kind` now, or at `at` when given. Only the drink grid passes the
  // time picked on the graph; hotkeys and IPC always mean "now". Unknown
  // kinds are refused rather than silently becoming espresso.
  function logDrink(kind, at) {
    var d = Model.drink(kind, drinksConfig)
    if (d.kind !== String(kind)) {
      lastError = "No drink called " + kind
      showFlash(lastError)
      return false
    }
    var when = at || new Date()
    var backdated = Math.abs(when.getTime() - Date.now()) > 90000
    var next = Model.parseLog(Model.serializeLog(log))
    var entry = { t: when.toISOString(), kind: d.kind, name: d.name, mg: d.mg }
    if (d.custom) entry.icon = d.icon
    next.drinks.push(entry)
    next.lastKind = d.kind
    if (!commitLog(next)) return false
    lastLogged = entry
    pickTime = null
    showFlash(d.name + (backdated ? " logged at " + Model.formatTime(when, timeFmt) : " logged")
      + " · +" + d.mg + " mg")
    return true
  }

  function logLast() { logDrink(lastKind) }

  function logAt(kind, timeText) {
    var parsed = Model.parseBedtime(timeText)
    if (!parsed) {
      lastError = "Time needs to look like " + bedtimeLabel
      showFlash(lastError)
      return false
    }
    var reference = new Date()
    var when = new Date(reference.getFullYear(), reference.getMonth(), reference.getDate(),
      parsed.hours, parsed.minutes, 0, 0)
    if (when.getTime() > reference.getTime()) when = Model.addDays(when, -1)
    return logDrink(kind, when)
  }

  function undoLast() {
    var target = null
    if (lastLogged) {
      for (var i = 0; i < log.drinks.length; i++)
        if (log.drinks[i].t === lastLogged.t && log.drinks[i].kind === lastLogged.kind) target = log.drinks[i]
    }
    if (!target) target = Model.lastDrink(log.drinks)
    if (!target) return
    if (!removeDrink(target)) return
    lastLogged = null
    showFlash("Removed " + target.name)
  }

  function removeDrink(drink) {
    var next = Model.parseLog(Model.serializeLog(log))
    for (var i = next.drinks.length - 1; i >= 0; i--) {
      if (next.drinks[i].t === drink.t && next.drinks[i].kind === drink.kind) {
        next.drinks.splice(i, 1)
        break
      }
    }
    return commitLog(next)
  }

  function commitLog(next) {
    if (!logLoaded) {
      lastError = "Log file not loaded or not readable · nothing written"
      showFlash(lastError)
      logFile.reload()
      return false
    }
    now = new Date()
    log = Model.pruneLog(next, now)
    logFile.setText(Model.serializeLog(log))
    return true
  }

  function showFlash(text) {
    flash = text
    flashVisible = true
    flashTimer.restart()
  }

  // ---- drinks: custom drinks and overrides --------------------------------
  function commitDrinks(next) {
    if (!drinksLoaded) {
      lastError = "Drinks file not loaded or not readable · nothing written"
      showFlash(lastError)
      drinksFile.reload()
      return false
    }
    drinksConfig = next
    drinksFile.setText(Model.serializeDrinksConfig(next))
    return true
  }

  function openEditor(kind) {
    var d = Model.drink(kind, drinksConfig)
    if (d.kind !== kind) return
    editing = { kind: d.kind, custom: d.custom, isNew: false }
    draftName = d.name
    draftMg = d.mg
    draftIcon = d.icon
    page = "drink"
  }

  function openNewDrink() {
    editing = { kind: "", custom: true, isNew: true }
    draftName = ""
    draftMg = 100
    draftIcon = "mug"
    page = "drink"
  }

  function saveEditor() {
    if (!editing) return
    var next = Model.cloneDrinksConfig(drinksConfig)
    var mg = Model.cleanMg(draftMg) || 0
    var name = Model.cleanName(draftName, "My drink")
    var message = ""
    if (editing.custom) {
      if (editing.isNew) {
        next.custom.push({ kind: Model.newCustomKind(), name: name, mg: mg, icon: draftIcon })
      } else {
        for (var i = 0; i < next.custom.length; i++) {
          if (next.custom[i].kind !== editing.kind) continue
          next.custom[i].name = name
          next.custom[i].mg = mg
          next.custom[i].icon = draftIcon
        }
      }
      message = name + " saved · " + mg + " mg"
    } else {
      if (mg === Model.preset(editing.kind).mg) delete next.overrides[editing.kind]
      else next.overrides[editing.kind] = mg
      message = Model.preset(editing.kind).name + " is now " + mg + " mg"
    }
    if (!commitDrinks(next)) return      // keep the draft and the page
    showFlash(message)
    editing = null
    page = "main"
  }

  function resetEditorMg() {
    if (!editing || editing.custom) return
    draftMg = Model.preset(editing.kind).mg
  }

  function deleteEditing() {
    if (!editing || !editing.custom || editing.isNew) return
    var next = Model.cloneDrinksConfig(drinksConfig)
    next.custom = next.custom.filter(function(c) { return c.kind !== editing.kind })
    if (!commitDrinks(next)) return
    showFlash("Deleted " + draftName)
    editing = null
    page = "main"
  }

  function resetAllOverrides() {
    var next = Model.cloneDrinksConfig(drinksConfig)
    next.overrides = {}
    if (commitDrinks(next)) showFlash("Every preset back to its default mg")
  }

  // ---- settings persistence ---------------------------------------------
  // The host reports "nothing changed" as false, so an unchanged value
  // must not fall through to the CLI. Same-value writes are skipped here.
  function saveSetting(key, value) {
    var current = settings || {}
    if (current.hasOwnProperty(key) && String(current[key]) === String(value)) return
    var next = {}
    for (var k in current) if (k !== "id") next[k] = current[k]
    next[key] = value
    var ok = false
    if (shell && typeof shell.updateEntryInline === "function")
      ok = shell.updateEntryInline(moduleName, next)
    if (!ok && bar && typeof bar.run === "function") {
      bar.run("omarchy bar set " + moduleName + " " + key + " "
        + JSON.stringify(String(value)))
      ok = true
    }
    if (ok) settings = next
  }

  // Pounds are stored as whole kilograms, and one pound is less than one
  // kilogram, so a single step in the field must still move the stored
  // value or the spinner would appear stuck.
  // Click on the cup: the other view, with the liquid gliding to the new
  // level instead of jumping.
  function toggleCupMode() {
    cup.flip()
    saveSetting("cupMode", cupShowsBody ? "Today's intake" : "In your system")
  }

  function saveWeight(shown) {
    if (!imperial) { saveSetting("bodyWeightKg", shown); return }
    var kg = Model.lbToKg(shown)
    if (kg === bodyWeightKg && shown !== weightShown) kg += shown > weightShown ? 1 : -1
    saveSetting("bodyWeightKg", Math.max(1, kg))
  }

  function commitBedtime() {
    if (!Model.validBedtime(bedtimeDraft)) {
      bedtimeDraft = bedtimeLabel
      showFlash("Bedtime needs a time like " + bedtimeLabel)
      return
    }
    var normalized = Model.normalizedBedtime(bedtimeDraft)
    if (normalized !== bedtime) saveSetting("bedtime", normalized)
    bedtimeDraft = Model.formatTime(Model.bedtimeAsDate(normalized, now), timeFmt)
  }

  // Computed from the raw inputs rather than `bedtimeLabel`: when a change
  // handler runs, dependent bindings may not have been re-evaluated yet.
  function syncBedtimeDraft() {
    var stored = Model.normalizedBedtime(setting("bedtime", "23:00"))
    bedtimeDraft = Model.formatTime(Model.bedtimeAsDate(stored, new Date()),
      Model.timeFormatFromClock(clockFormat))
  }

  onSettingsChanged: syncBedtimeDraft()
  onClockFormatChanged: syncBedtimeDraft()
  Component.onCompleted: {
    syncBedtimeDraft()
    ensureDirs.running = true
  }

  Process {
    id: ensureDirs
    command: ["mkdir", "-p", root.stateDir + "/omacaffeine", root.configDir + "/omacaffeine"]
    onExited: {
      logFile.reload()
      drinksFile.reload()
    }
  }

  Process {
    id: tokensProcess
    command: ["python3", root.pluginDir + "/tokens.py", "8"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = null
        try { parsed = JSON.parse(text) } catch (e) {}
        if (parsed && parsed.hours && typeof parsed.hours === "object") {
          if (!parsed.sources) parsed.sources = {}
          root.tokens = parsed
          root.tokensFetchedAt = Date.now()
          root.tokensState = "ok"
        } else {
          root.tokensState = "failed"
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) root.tokensState = "failed"
    }
  }

  FileView {
    id: logFile
    path: root.logPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: {
      var parsed = Model.parseLogOrNull(text())
      if (parsed) {
        root.log = Model.pruneLog(parsed, new Date())
        root.logLoaded = true
      } else {
        // Not something we wrote: keep the display, refuse to write over it.
        root.logLoaded = false
        root.lastError = "log.json is not a log I understand · leaving it alone"
        root.showFlash(root.lastError)
      }
    }
    // A missing file on first load is a fresh install. A missing file later
    // (deleted by hand, or a transient miss during our own atomic rename)
    // keeps memory and stays writable. Any other failure blocks writes.
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) {
        if (!root.logLoaded) {
          root.log = Model.emptyLog()
          root.logLoaded = true
        }
        return
      }
      root.logLoaded = false
      root.lastError = "Cannot read log.json (" + FileViewError.toString(error) + ")"
      root.showFlash(root.lastError)
    }
    onSaveFailed: function(error) {
      root.lastError = "Could not write log.json (" + FileViewError.toString(error) + ")"
      root.showFlash(root.lastError)
      console.warn("omacaffeine: " + root.lastError)
    }
  }

  FileView {
    id: drinksFile
    path: root.drinksPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: {
      var parsed = Model.parseDrinksConfigOrNull(text())
      if (parsed) {
        root.drinksConfig = parsed
        root.drinksLoaded = true
      } else {
        root.drinksLoaded = false
        root.lastError = "drinks.json is not a drinks file I understand · leaving it alone"
        root.showFlash(root.lastError)
      }
    }
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) {
        if (!root.drinksLoaded) {
          root.drinksConfig = Model.emptyDrinksConfig()
          root.drinksLoaded = true
        }
        return
      }
      root.drinksLoaded = false
      root.lastError = "Cannot read drinks.json (" + FileViewError.toString(error) + ")"
      root.showFlash(root.lastError)
    }
    onSaveFailed: function(error) {
      root.lastError = "Could not write drinks.json (" + FileViewError.toString(error) + ")"
      root.showFlash(root.lastError)
      console.warn("omacaffeine: " + root.lastError)
    }
  }

  FileView {
    id: shellConfigFile
    path: root.shellConfigPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.clockFormat = Model.clockFormatFromShellConfig(text())
    onLoadFailed: root.clockFormat = ""
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  Timer {
    id: flashTimer
    interval: 2600
    onTriggered: root.flashVisible = false
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function log(kind: string): string {
      return root.logDrink(kind) ? root.todayMg + " mg today" : "error: " + root.lastError
    }
    function logAt(kind: string, time: string): string {
      return root.logAt(kind, time) ? root.todayMg + " mg today" : "error: " + root.lastError
    }
    function logLast(): string {
      return root.logDrink(root.lastKind) ? root.todayMg + " mg today" : "error: " + root.lastError
    }
    function undo(): void { root.undoLast() }
    function settings(): void { root.openFromHotkey(); root.showPage("settings") }
    function week(): void { root.openFromHotkey(); root.showPage("week") }
    function edit(kind: string): void {
      root.openFromHotkey()
      if (!kind || kind === "new") root.openNewDrink()
      else root.openEditor(kind)
    }
    function drinks(): string {
      return root.drinks.map(function(d) { return d.kind + " " + d.mg + " mg" }).join("\n")
    }
    function status(): string {
      return root.todayMg + " mg of " + root.dailyLimitMg + " (" + root.todayPercent
        + "%) · " + root.today.length + (root.today.length === 1 ? " drink · " : " drinks · ")
        + root.statusLine
    }
  }

  // ---- UI ----------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(540))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: bedtimeField.activeFocus || nameField.activeFocus || weightField.field.activeFocus
        || dailyField.field.activeFocus || bedLimitField.field.activeFocus || mgField.field.activeFocus
      onReturnRequested: {
        if (root.page === "main") root.logLast()
        else if (root.page === "drink") root.saveEditor()
      }
      onCloseRequested: if (!root.goBack()) root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroll.width
          spacing: Style.space(12)

          // ================= header =================
          Item {
            width: parent.width
            height: Style.space(30)

            PanelActionButton {
              id: backButton
              visible: root.page !== "main"
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰁍"
              tooltipText: "Back (Esc)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.goBack()
            }
            Text {
              id: headerIcon
              visible: root.page === "main"
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "󰅶"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.iconLarge
            }
            Text {
              id: headerTitle
              anchors.left: root.page === "main" ? headerIcon.right : backButton.right
              anchors.leftMargin: Style.space(8)
              anchors.right: headerFlash.visible ? headerFlash.left : headerButtons.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.page === "main" ? "OmaCaffeine"
                : (root.page === "settings" ? "Settings"
                : (root.page === "week" ? Model.weekHeading(root.seed)
                : (root.editing && root.editing.isNew ? "New drink" : "Edit " + root.draftName)))
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }
            // Off the main page the cup is not there to carry the flash, so
            // it fades in next to the buttons instead.
            Text {
              id: headerFlash
              visible: root.page !== "main"
              anchors.right: headerButtons.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, Style.space(260))
              text: root.flash
              textFormat: Text.PlainText
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideLeft
              opacity: root.flashVisible ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutSine } }
            }

            Row {
              id: headerButtons
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              PanelActionButton {
                visible: root.page === "main"
                iconText: "󰕌"
                tooltipText: "Undo last drink"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: root.last !== null
                opacity: enabled ? 1 : 0.4
                onClicked: root.undoLast()
              }
              PanelActionButton {
                visible: root.page === "main"
                iconText: "󰄨"
                tooltipText: "Last seven days"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.showPage("week")
              }
              PanelActionButton {
                visible: root.page === "main"
                iconText: "󰒓"
                tooltipText: "Settings"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.showPage("settings")
              }
              PanelActionButton {
                iconText: "✕"
                tooltipText: "Close"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.close()
              }
            }
          }

          // ================= main page =================
          Item {
            visible: root.page === "main"
            width: parent.width
            height: Math.max(cup.height, stats.implicitHeight)

            CaffeineCup {
              id: cup
              width: Style.space(160)
              height: Style.space(160)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              level: root.cupLevel
              active: root.opened
              foreground: root.foreground
              urgent: root.urgent
              fontFamily: root.fontFamily
              label: Math.round(cup.shownValue * 100) + "%"
              sublabel: root.cupLevel > 1 ? "stack overflow"
                : (root.cupShowsBody ? root.inBodyMg + " mg in you"
                  : root.todayMg + " / " + root.dailyLimitMg + " mg")

              MouseArea {
                id: cupArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleCupMode()
              }
              PanelToolTip {
                visible: cupArea.containsMouse
                text: root.cupShowsBody
                  ? "In your system right now · click for today's intake"
                  : "Today's intake · click for what is in your system now"
              }
            }

            // The confirmation floats over the steam and fades, so nothing
            // below it moves.
            Text {
              id: flashText
              // Errors can be long; let the text run across the row rather
              // than elide what the user needs to read.
              readonly property real maxWidth: parent.width
              x: Math.max(0, cup.x + cup.width / 2 - width / 2)
              y: 0
              width: Math.min(implicitWidth, maxWidth)
              text: root.flash
              textFormat: Text.PlainText
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              opacity: root.flashVisible ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.InOutSine } }
            }

            Column {
              id: stats
              anchors.left: cup.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(10)

              ScrollingText {
                width: parent.width
                active: root.opened
                text: root.firstLine
                color: root.first ? root.foreground : root.accent
                fontFamily: root.fontFamily
                pixelSize: Style.font.body
                bold: !root.first
              }

              Column {
                width: parent.width
                spacing: Style.space(5)

                StatRow {
                  label: "Today"
                  value: root.todayMg + " of " + root.dailyLimitMg + " mg · " + root.todayPercent
                    + "% · " + root.today.length + (root.today.length === 1 ? " drink" : " drinks")
                  valueColor: root.overLimit ? root.urgent : root.foreground
                }
                StatRow {
                  label: "In your system"
                  value: root.inBodyMg > 0
                    ? root.inBodyMg + " mg · " + (root.caffeineFreeAt
                      ? "gone by ~" + Model.formatTimeFrom(root.caffeineFreeAt, root.now, root.timeFmt)
                      : "not gone for days")
                    : "0 mg · clean slate"
                }
                StatRow {
                  label: "Bedtime " + root.bedtimeLabel
                  value: Math.round(root.cutoff.atBedtime) + " mg left · limit " + root.bedtimeLimitMg + " mg"
                  valueColor: root.cutoff.atBedtime > root.bedtimeLimitMg ? root.urgent : root.foreground
                }
              }

              // Cut-off: information, not a control.
              Item {
                width: parent.width
                height: Style.space(22)

                Text {
                  id: cutoffIcon
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.cutoffIcon(root.cutoff.status)
                  color: root.cutoffOk ? root.accent : root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.icon
                }
                ScrollingText {
                  anchors.left: cutoffIcon.right
                  anchors.leftMargin: Style.space(8)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  active: root.opened
                  text: root.statusLine
                  color: root.cutoffOk ? root.accent : root.urgent
                  fontFamily: root.fontFamily
                  pixelSize: Style.font.bodySmall
                  bold: true
                }
              }
            }
          }

          PanelSectionHeader {
            visible: root.page === "main"
            width: parent.width
            text: root.gridHeading.toUpperCase()
            foreground: root.pickTime ? root.accent : root.foreground
            fontFamily: root.fontFamily
          }

          Grid {
            id: drinkGrid
            visible: root.page === "main"
            width: parent.width
            columns: root.gridColumns
            columnSpacing: Style.space(6)
            rowSpacing: Style.space(6)
            readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

            Repeater {
              model: root.gridModel

              BorderSurface {
                required property var modelData
                readonly property bool placeholder: modelData.placeholder === true
                readonly property bool isLast: !placeholder && modelData.kind === root.lastKind
                width: drinkGrid.cellWidth
                height: Style.space(62)
                radius: Style.cornerRadius
                color: isLast
                  ? Style.selectedFillFor(root.foreground, root.accent)
                  : (drinkArea.containsMouse
                    ? Style.hoverFillFor(root.foreground, root.accent)
                    : Style.normalFillFor(root.foreground, root.accent))
                borderSpec: Border.controlSpec(isLast ? "selected"
                  : (drinkArea.containsMouse ? "hover-cursor" : "normal"),
                  root.foreground, root.accent)
                opacity: placeholder && !drinkArea.containsMouse ? 0.6 : 1

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  DrinkIcon {
                    visible: !placeholder
                    anchors.horizontalCenter: parent.horizontalCenter
                    kind: placeholder ? "mug" : modelData.icon
                    size: Style.space(22)
                    strokeWidth: 1.7
                    color: isLast ? root.accent : root.foreground
                  }
                  Text {
                    visible: placeholder
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰐕"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.iconLarge
                    height: Style.space(22)
                    verticalAlignment: Text.AlignVCenter
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, drinkGrid.cellWidth - Style.space(8))
                    text: placeholder ? "Create my own" : modelData.name
                    textFormat: Text.PlainText
                    color: placeholder ? root.dim : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: isLast
                    elide: Text.ElideRight
                  }
                  Text {
                    visible: !placeholder
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.mg + " mg" + (modelData.overridden ? " ·" : "")
                    color: modelData.overridden ? root.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: drinkArea
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    if (placeholder) root.openNewDrink()
                    else if (mouse.button === Qt.RightButton) root.openEditor(modelData.kind)
                    else root.logDrink(modelData.kind, root.pickTime)
                  }
                }

                PanelToolTip {
                  visible: drinkArea.containsMouse
                  text: placeholder
                    ? "Name it, set the mg, pick an icon"
                    : modelData.serving + " · " + modelData.mg + " mg caffeine"
                      + (modelData.overridden ? " (default " + modelData.defaultMg + ")" : "")
                      + " · right-click to edit"
                }
              }
            }
          }

          PanelSectionHeader {
            visible: root.page === "main"
            width: parent.width
            text: root.pickTime
              ? "TIMELINE · NOW PICK A DRINK ABOVE, OR CLICK AGAIN TO MOVE THE TIME"
              : "TIMELINE · INTAKE, HALF-LIFE AND BEDTIME · CLICK TO LOG BACK IN TIME"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          CaffeineGraph {
            visible: root.page === "main"
            width: parent.width
            height: Style.space(112)
            drinks: root.log.drinks
            now: root.now
            bedtime: root.cutoff.bedtime
            halfLife: root.halfLife
            bedtimeLimit: root.bedtimeLimitMg
            foreground: root.foreground
            accent: root.accent
            urgent: root.urgent
            fontFamily: root.fontFamily
            timeFormat: root.timeFmt
            pickTime: root.pickTime
            onPicked: function(time) {
              // A click in the future, or on the time already picked, cancels.
              if (!time || (root.pickTime && root.pickTime.getTime() === time.getTime())) {
                root.pickTime = null
                return
              }
              root.pickTime = time
            }
          }

          PanelSectionHeader {
            visible: root.page === "main" && root.today.length > 0
            width: parent.width
            text: "TODAY'S LOG" + (root.today.length > 3
              ? " · " + root.today.length + " DRINKS · SCROLL FOR THE REST" : "")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          // Three rows on screen; the rest scroll inside, so the panel does
          // not grow with every cup.
          Flickable {
            id: logScroll
            readonly property int rowHeight: Style.space(24)
            readonly property int rowGap: Style.space(2)
            visible: root.page === "main" && root.today.length > 0
            width: parent.width
            height: Math.min(logColumn.implicitHeight, rowHeight * 3 + rowGap * 2)
            contentWidth: width
            contentHeight: logColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
              id: logColumn
              width: logScroll.width
              spacing: logScroll.rowGap

              Repeater {
                model: root.today.slice().reverse()

                Item {
                  required property var modelData
                  width: parent.width
                  height: logScroll.rowHeight

                  Row {
                    id: logRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(36)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(10)

                    Text {
                      width: Style.space(64)
                      text: Model.formatTime(Model.drinkTime(modelData), root.timeFmt)
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    DrinkIcon {
                      kind: Model.iconFor(modelData, root.drinksConfig)
                      size: Style.space(18)
                      color: root.foreground
                      strokeWidth: 1.8
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      width: Math.min(implicitWidth, logRow.width - Style.space(150))
                      text: modelData.name
                      textFormat: Text.PlainText
                      elide: Text.ElideRight
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                      text: modelData.mg + " mg"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  PanelActionButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "✕"
                    fontSize: Style.font.caption
                    tooltipText: "Remove"
                    foreground: root.dim
                    fontFamily: root.fontFamily
                    onClicked: root.removeDrink(modelData)
                  }
                }
              }
            }
          }

          // ================= drink editor =================
          Column {
            visible: root.page === "drink"
            width: parent.width
            spacing: Style.space(14)

            Row {
              width: parent.width
              spacing: Style.space(16)

              // Live preview: the tile exactly as the grid will show it.
              BorderSurface {
                width: Style.space(104)
                height: Style.space(62)
                anchors.verticalCenter: parent.verticalCenter
                radius: Style.cornerRadius
                color: Style.selectedFillFor(root.foreground, root.accent)
                borderSpec: Border.controlSpec("selected", root.foreground, root.accent)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  DrinkIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    kind: root.draftIcon
                    size: Style.space(22)
                    strokeWidth: 1.7
                    color: root.accent
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, Style.space(96))
                    text: root.draftName.trim() || "My drink"
                    textFormat: Text.PlainText
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.draftMg + " mg"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }

              Column {
                spacing: Style.space(4)
                visible: root.editing !== null && root.editing.custom
                Text {
                  text: "Name"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                TextField {
                  id: nameField
                  width: Style.space(180)
                  text: root.draftName
                  maximumLength: Model.MAX_NAME
                  placeholderText: "Batch brew"
                  foreground: root.foreground
                  accent: root.accent
                  font.family: root.fontFamily
                  onTextEdited: root.draftName = text
                  onAccepted: root.saveEditor()
                }
              }

              NumberField {
                id: mgField
                label: "Caffeine (mg)"
                value: root.draftMg
                from: 0
                to: Model.MAX_MG
                stepSize: 1
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.draftMg = v }
              }
            }

            Text {
              width: parent.width
              visible: root.editing !== null && !root.editing.custom
              text: root.editing && !root.editing.custom
                ? Model.preset(root.editing.kind).serving + " · default " + Model.preset(root.editing.kind).mg
                  + " mg. Your espresso is a double? Make it 126 mg here; the log keeps the mg each cup had when it was logged."
                : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            PanelSectionHeader {
              visible: root.editing !== null && root.editing.custom
              width: parent.width
              text: "ICON"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              id: iconGrid
              visible: root.editing !== null && root.editing.custom
              width: parent.width
              columns: 8
              columnSpacing: Style.space(6)
              rowSpacing: Style.space(6)
              readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

              Repeater {
                model: Model.ICON_KINDS

                BorderSurface {
                  required property var modelData
                  readonly property bool picked: modelData === root.draftIcon
                  width: iconGrid.cellWidth
                  height: Style.space(40)
                  radius: Style.cornerRadius
                  color: picked
                    ? Style.selectedFillFor(root.foreground, root.accent)
                    : (iconArea.containsMouse
                      ? Style.hoverFillFor(root.foreground, root.accent)
                      : Style.normalFillFor(root.foreground, root.accent))
                  borderSpec: Border.controlSpec(picked ? "selected"
                    : (iconArea.containsMouse ? "hover-cursor" : "normal"),
                    root.foreground, root.accent)

                  DrinkIcon {
                    anchors.centerIn: parent
                    kind: modelData
                    size: Style.space(22)
                    strokeWidth: 1.7
                    color: picked ? root.accent : root.foreground
                  }
                  MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.draftIcon = modelData
                  }
                }
              }
            }

            Row {
              spacing: Style.space(8)

              Button {
                bordered: true
                text: root.editing && root.editing.isNew ? "Create drink" : "Save"
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.saveEditor()
              }
              Button {
                visible: root.editing !== null && !root.editing.custom
                bordered: true
                text: "Reset to default (" + (root.editing && !root.editing.custom ? Model.preset(root.editing.kind).mg : 0) + " mg)"
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                enabled: root.editing !== null && !root.editing.custom && root.draftMg !== Model.preset(root.editing.kind).mg
                opacity: enabled ? 1 : 0.5
                onClicked: root.resetEditorMg()
              }
              Button {
                visible: root.editing !== null && root.editing.custom && !root.editing.isNew
                bordered: true
                text: "Delete"
                foreground: root.urgent
                accent: root.urgent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.deleteEditing()
              }
            }
          }

          // ================= week page =================
          Column {
            visible: root.page === "week"
            width: parent.width
            spacing: Style.space(14)

            PanelSectionHeader {
              width: parent.width
              text: "LAST SEVEN DAYS · AVERAGE " + root.weekAvgMg + " MG/DAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            // One column per day: a small cup, the mg, the weekday and the
            // cups. The agents' tokens follow in a second, labelled row that
            // lines up with the same columns.
            Row {
              id: weekRow
              width: parent.width
              spacing: Style.space(8)
              readonly property real cellWidth: (width - spacing * 6) / 7

              Repeater {
                model: root.week

                Column {
                  required property var modelData
                  required property int index
                  width: weekRow.cellWidth
                  spacing: Style.space(3)

                  CaffeineCup {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, Style.space(64))
                    height: width
                    level: modelData.mg / root.dailyLimitMg
                    animated: false
                    foreground: root.foreground
                    urgent: root.urgent
                    fontFamily: root.fontFamily
                    opacity: modelData.isToday || modelData.mg > 0 ? 1 : 0.45
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.mg + " mg"
                    color: modelData.mg > root.dailyLimitMg ? root.urgent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: modelData.isToday
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.isToday ? "Today" : modelData.label
                    color: modelData.isToday ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: modelData.isToday
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.count + (modelData.count === 1 ? " cup" : " cups")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            // The token row: what your agents wrote each day, same columns.
            Column {
              width: parent.width
              spacing: Style.space(4)

              Row {
                spacing: Style.space(6)
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰚩"
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.icon
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "OUTPUT TOKENS PER DAY · WHAT YOUR CODING AGENTS WROTE"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.5
                }
              }

              Row {
                width: parent.width
                spacing: weekRow.spacing

                Repeater {
                  model: root.week

                  Column {
                    required property var modelData
                    required property int index
                    readonly property int dayTokens: root.weekTokens[index] || 0
                    width: weekRow.cellWidth
                    spacing: Style.space(3)

                    Item {
                      width: parent.width
                      height: Style.space(36)
                      Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.6
                        height: Math.max(dayTokens > 0 ? 2 : 0, parent.height * dayTokens / root.weekTokenMax)
                        radius: 1
                        color: root.accent
                        opacity: modelData.isToday ? 0.95 : 0.7
                        Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                      }
                      Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: root.dim
                        opacity: 0.4
                      }
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: dayTokens > 0 ? "󰚩 " + Model.formatTokens(dayTokens) : "–"
                      color: modelData.isToday ? root.foreground : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(5)

              StatRow {
                label: "Caffeine"
                value: root.weekMgTotal + " mg this week · " + root.weekAvgDrinks.toFixed(1) + " cups/day"
                  + (root.weekPeak && root.weekPeak.mg > 0
                    ? " · peak " + (root.weekPeak.isToday ? "today" : root.weekPeak.label) + " " + root.weekPeak.mg + " mg" : "")
              }
              StatRow {
                label: "Tokens"
                value: root.tokensState === "failed"
                  ? "tokens.py failed · is python3 installed?"
                  : (root.tokensState === "loading" && root.weekTokenTotal === 0 ? "Scanning transcripts…"
                  : (root.weekTokenTotal > 0
                    ? Model.formatTokens(root.weekTokenTotal) + " output tokens · "
                      + Model.formatTokens(root.weekTokenTotal / 7) + "/day"
                      + (root.weekMgTotal > 0 ? " · " + Model.formatTokens(root.weekTokenTotal / root.weekMgTotal) + " per mg" : "")
                    : "No agent transcripts found this week"))
              }
              StatRow {
                label: "Trend"
                value: "caffeine " + Model.describeTrend(root.mgSlope, "mg")
                  + " · tokens " + Model.describeTrend(root.tokenSlope, "tok", Model.formatTokens)
              }
            }

            PanelSectionHeader {
              width: parent.width
              text: "CAFFEINE × 󰚩 TOKENS · OUTPUT PER ACTIVE HOUR, BY MG IN YOUR SYSTEM"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: root.buckets

                Item {
                  required property var modelData
                  readonly property bool best: root.sweetSpot !== null && root.sweetSpot.label === modelData.label
                  width: parent.width
                  height: Style.space(16)

                  Text {
                    id: bucketLabel
                    width: Style.space(84)
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: best ? root.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: best
                  }
                  Rectangle {
                    id: bucketBar
                    anchors.left: bucketLabel.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(modelData.hours > 0 ? 2 : 0,
                      (parent.width - bucketLabel.width - Style.space(150)) * modelData.perHour / root.bucketMax)
                    height: Style.space(8)
                    radius: 1
                    color: root.accent
                    opacity: best ? 1 : 0.55
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.InOutSine } }
                  }
                  Text {
                    anchors.left: bucketBar.right
                    anchors.leftMargin: Style.space(8)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.hours > 0
                      ? "󰚩 " + Model.formatTokens(modelData.perHour) + " tok/h · " + modelData.hours + (modelData.hours === 1 ? " hour" : " hours")
                      : "no hours at this level"
                    color: best ? root.foreground : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(3)

              ScrollingText {
                width: parent.width
                active: root.opened
                text: root.sweetSpot
                  ? "Sweet spot: " + root.sweetSpot.label + " in your system · "
                    + Model.formatTokens(root.sweetSpot.perHour) + " tokens/hour"
                  : "No sweet spot yet · two active hours at one level is all it takes"
                color: root.accent
                fontFamily: root.fontFamily
                pixelSize: Style.font.bodySmall
                bold: true
              }
              ScrollingText {
                width: parent.width
                active: root.opened
                text: Model.describeCorrelation(root.hourR, root.activeHours.length)
                color: root.dim
                fontFamily: root.fontFamily
                pixelSize: Style.font.caption
              }
            }

            Text {
              width: parent.width
              text: "Correlation, not causation. Tokens are output tokens (thinking included) from Claude Code and Codex transcripts on this machine"
                + (root.sourceFiles > 0 ? " (" + root.sourceFiles + " sessions this week)" : "")
                + "; an hour counts as active when any agent produced tokens. Caffeine is the half-life model over your log. Both mostly measure \"at the keyboard\", so drink for the taste."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ================= settings page =================
          Column {
            visible: root.page === "settings"
            width: parent.width
            spacing: Style.space(14)

            PanelSectionHeader {
              width: parent.width
              text: "YOU"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(16)

              NumberField {
                id: weightField
                label: "Body weight (" + root.weightUnit + ")"
                value: root.weightShown
                from: root.imperial ? 66 : 30
                to: root.imperial ? 550 : 250
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.saveWeight(v) }
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)
                Text {
                  text: "Recommended daily limit: " + root.recommendedDaily + " mg (5.7 mg/kg, max 400)"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  text: "Single dose up to " + root.singleDose + " mg (3 mg/kg)"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(4)
              Text {
                text: "Typical day"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              ButtonGroup {
                options: Model.ACTIVITIES
                value: root.activity
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onChanged: function(v) { root.saveSetting("activity", v) }
              }
              Text {
                width: parent.width
                text: "Half-life used: " + root.halfLife + " h. Adults average about 5 h; moving around clears caffeine a little faster."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            PanelSectionHeader {
              width: parent.width
              text: "LIMITS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(16)

              Column {
                spacing: Style.space(4)
                Text {
                  text: "Optimal bedtime"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                TextField {
                  id: bedtimeField
                  width: Style.space(104)
                  text: root.bedtimeDraft
                  placeholderText: root.bedtimeLabel
                  foreground: root.foreground
                  accent: root.accent
                  font.family: root.fontFamily
                  onTextEdited: root.bedtimeDraft = text
                  onAccepted: root.commitBedtime()
                  onActiveFocusChanged: if (!activeFocus) root.commitBedtime()
                }
              }
              NumberField {
                id: dailyField
                label: "Daily limit (mg)"
                value: root.dailyLimitMg
                from: 50
                to: 1000
                stepSize: 10
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.saveSetting("dailyLimitMg", v) }
              }
              NumberField {
                id: bedLimitField
                label: "At bedtime (mg)"
                value: root.bedtimeLimitMg
                from: 5
                to: 200
                stepSize: 5
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.saveSetting("bedtimeLimitMg", v) }
              }
            }

            Button {
              bordered: true
              text: "Use recommended limit (" + root.recommendedDaily + " mg)"
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              enabled: root.dailyLimitMg !== root.recommendedDaily
              opacity: enabled ? 1 : 0.5
              onClicked: root.saveSetting("dailyLimitMg", root.recommendedDaily)
            }

            PanelSectionHeader {
              width: parent.width
              text: "DRINKS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              width: parent.width
              text: Model.PRESETS.length + " presets · " + Model.overrideCount(root.drinksConfig)
                + " with your own mg · " + root.drinksConfig.custom.length + " of your own drinks. "
                + "Right-click any drink on the main page to change its mg, or use the + tile to create one (name, mg, icon)."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Button {
              bordered: true
              text: "Reset every preset to its default mg"
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              enabled: Model.overrideCount(root.drinksConfig) > 0
              opacity: enabled ? 1 : 0.5
              onClicked: root.resetAllOverrides()
            }

            PanelSectionHeader {
              width: parent.width
              text: "BAR"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(4)
              Text {
                text: "Cup shows"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              ButtonGroup {
                options: ["Today's intake", "In your system"]
                value: root.cupMode
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onChanged: function(v) { root.saveSetting("cupMode", v) }
              }
              Text {
                width: parent.width
                text: "Today's intake fills up as you drink. In your system follows the half-life and drains between cups."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(4)
              Text {
                text: "Bar shows"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              ButtonGroup {
                options: ["Icon", "Milligrams", "Percent"]
                value: root.barDisplay
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onChanged: function(v) { root.saveSetting("barDisplay", v) }
              }
              Text {
                width: parent.width
                text: "Times follow the Omarchy clock widget (" + (root.timeFmt === "HH:mm" ? "24-hour" : "12-hour") + ")."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            Text {
              width: parent.width
              text: "Model: first-order elimination with a fixed half-life; every drink counts as fully absorbed when logged. Limits follow EFSA guidance for healthy adults (400 mg/day, 200 mg per dose, 100 mg near bedtime may affect sleep). Not medical advice — just a nerd with a mug."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ================= footer =================
          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          Text {
            width: parent.width
            text: Model.quote(root.seed)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.italic: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // Label column and value on a shared baseline; the value never wraps.
  component StatRow: Item {
    property string label: ""
    property string value: ""
    property color valueColor: root.foreground
    width: parent ? parent.width : 0
    height: Math.max(labelText.implicitHeight, valueText.height)

    Text {
      id: labelText
      width: Style.space(112)
      anchors.left: parent.left
      anchors.baseline: valueText.baseline
      text: label.toUpperCase()
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.5
      elide: Text.ElideRight
    }
    ScrollingText {
      id: valueText
      anchors.left: labelText.right
      anchors.right: parent.right
      anchors.top: parent.top
      active: root.opened
      text: value
      color: valueColor
      fontFamily: root.fontFamily
      pixelSize: Style.font.bodySmall
    }
  }
}
