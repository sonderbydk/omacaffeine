import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// OmaCaffeine panel: log a drink, watch the cup fill, and see the cut-off
// for tonight. State lives in ~/.local/state/omacaffeine/log.json; the
// settings live inline on the bar entry in shell.json like every widget.
Panel {
  id: root
  moduleName: "io.github.sonderbydk.omacaffeine"
  ipcTarget: "io.github.sonderbydk.omacaffeine"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var shell: null
  property bool openedFromHotkey: false
  readonly property var barIdentity: hostWidget || root

  // ---- state -------------------------------------------------------------
  property var log: Model.emptyLog()
  property date now: new Date()
  property bool settingsOpen: false
  property int quoteSeed: Math.floor(Math.random() * 1000)
  property string bedtimeDraft: ""
  property string flash: ""

  readonly property string stateDir: Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")
  readonly property string logPath: stateDir + "/omacaffeine/log.json"

  // ---- settings ----------------------------------------------------------
  readonly property int bodyWeightKg: Math.max(1, Number(setting("bodyWeightKg", 80)) || 80)
  readonly property string activity: String(setting("activity", "Sitting"))
  readonly property string bedtime: Model.normalizedBedtime(setting("bedtime", "23:00"))
  readonly property int dailyLimitMg: Math.max(1, Number(setting("dailyLimitMg", 400)) || 400)
  readonly property int bedtimeLimitMg: Math.max(0, Number(setting("bedtimeLimitMg", Model.DEFAULT_BEDTIME_LIMIT)) || 0)
  readonly property real halfLife: Model.halfLifeHours(activity)
  readonly property int recommendedDaily: Model.recommendedDailyLimit(bodyWeightKg)
  readonly property int singleDose: Model.singleDoseLimit(bodyWeightKg)
  readonly property bool imperial: Model.usesImperialWeight()
  readonly property string weightUnit: imperial ? "lb" : "kg"
  readonly property int weightShown: imperial ? Model.kgToLb(bodyWeightKg) : bodyWeightKg

  // ---- derived -----------------------------------------------------------
  readonly property var today: Model.todaysDrinks(log.drinks, now)
  readonly property int todayMg: Model.totalMg(today)
  readonly property int todayPercent: Math.round(todayMg / dailyLimitMg * 100)
  readonly property real level: todayMg / dailyLimitMg
  readonly property bool overLimit: todayMg > dailyLimitMg
  readonly property var first: Model.firstDrink(today)
  readonly property var last: Model.lastDrink(log.drinks)
  readonly property string lastKind: last ? String(last.kind) : String(log.lastKind || "espresso")
  readonly property var lastPreset: Model.preset(lastKind)
  readonly property int inBodyMg: Math.round(Model.inBody(log.drinks, now, halfLife))
  readonly property var cutoff: Model.cutoff(log.drinks, now, bedtime, halfLife,
    bedtimeLimitMg, lastPreset.mg)
  readonly property var caffeineFreeAt: Model.timeUntilBelow(log.drinks, now, halfLife, 10)
  readonly property string bedtimeLabel: Model.formatTime(Model.bedtimeAsDate(bedtime, now))
  readonly property bool cutoffOk: cutoff.status === "clear" || cutoff.status === "until"
  readonly property string statusLine: {
    var c = cutoff
    if (c.status === "clear")
      return "Clear for bedtime · one more " + lastPreset.name + " still fits"
    if (c.status === "until")
      return "Cut-off " + Model.formatTimeFrom(c.time, now) + " for a " + lastPreset.name
    if (c.status === "passed")
      return "Past cut-off for a " + lastPreset.name + " · decaf from here"
    return "Over the bedtime limit · under " + bedtimeLimitMg + " mg by "
      + Model.formatTimeFrom(c.time, now)
  }
  readonly property string firstLine: first
    ? "First caffeine today: " + Model.formatTime(Model.drinkTime(first))
      + " · " + first.name
    : "Let's brew you some coffee — you deserve it!"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.4)

  // ---- lifecycle ---------------------------------------------------------
  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    refresh()
    root.controller.show()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    settingsOpen = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
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
    quoteSeed = Math.floor(Math.random() * 1000)
    logFile.reload()
  }

  // ---- log ---------------------------------------------------------------
  function logDrink(kind) {
    var p = Model.preset(kind)
    var next = Model.parseLog(Model.serializeLog(log))
    next.drinks.push({ t: new Date().toISOString(), kind: p.kind, name: p.name, mg: p.mg })
    next.lastKind = p.kind
    commitLog(next)
    showFlash(p.name + " logged · +" + p.mg + " mg")
  }

  function logLast() { logDrink(lastKind) }

  function undoLast() {
    var latest = Model.lastDrink(log.drinks)
    if (!latest) return
    removeDrink(latest)
    showFlash("Removed " + latest.name)
  }

  function removeDrink(drink) {
    var next = Model.parseLog(Model.serializeLog(log))
    for (var i = next.drinks.length - 1; i >= 0; i--) {
      if (next.drinks[i].t === drink.t && next.drinks[i].kind === drink.kind) {
        next.drinks.splice(i, 1)
        break
      }
    }
    commitLog(next)
  }

  function commitLog(next) {
    now = new Date()
    log = Model.pruneLog(next, now)
    logFile.setText(Model.serializeLog(log))
  }

  function showFlash(text) {
    flash = text
    flashTimer.restart()
  }

  // ---- settings persistence ---------------------------------------------
  function saveSetting(key, value) {
    var next = {}
    var current = settings || {}
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

  function saveWeight(shown) {
    saveSetting("bodyWeightKg", imperial ? Model.lbToKg(shown) : shown)
  }

  function commitBedtime() {
    if (!Model.validBedtime(bedtimeDraft)) {
      bedtimeDraft = bedtimeLabel
      showFlash("Bedtime needs a time like " + bedtimeLabel)
      return
    }
    var normalized = Model.normalizedBedtime(bedtimeDraft)
    if (normalized !== bedtime) saveSetting("bedtime", normalized)
    bedtimeDraft = Model.formatTime(Model.bedtimeAsDate(normalized, now))
  }

  onSettingsChanged: bedtimeDraft = bedtimeLabel
  Component.onCompleted: {
    bedtimeDraft = bedtimeLabel
    ensureStateDir.running = true
  }

  Process {
    id: ensureStateDir
    command: ["mkdir", "-p", root.stateDir + "/omacaffeine"]
    onExited: logFile.reload()
  }

  FileView {
    id: logFile
    path: root.logPath
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: root.log = Model.pruneLog(Model.parseLog(text()), new Date())
    onLoadFailed: root.log = Model.emptyLog()
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.now = new Date()
  }

  Timer {
    id: flashTimer
    interval: 2400
    onTriggered: root.flash = ""
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function log(kind: string): string {
      root.logDrink(kind)
      return root.todayMg + " mg today"
    }
    function logLast(): string {
      root.logLast()
      return root.todayMg + " mg today"
    }
    function undo(): void { root.undoLast() }
    function settings(): void { root.openFromHotkey(); root.settingsOpen = true }
    function status(): string {
      return root.todayMg + " mg of " + root.dailyLimitMg + " (" + root.todayPercent
        + "%) · " + root.today.length + " drinks · " + root.statusLine
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
      blocked: bedtimeField.activeFocus
      onReturnRequested: root.logLast()
      onCloseRequested: root.close()
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
          spacing: Style.space(14)

          // ---- header ----
          Item {
            width: parent.width
            height: headerRow.implicitHeight

            Row {
              id: headerRow
              spacing: Style.space(8)
              anchors.left: parent.left

              Text {
                text: "󰅶"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.iconLarge
                anchors.verticalCenter: parent.verticalCenter
              }
              Column {
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter
                Text {
                  text: "OmaCaffeine"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
                Text {
                  text: "fuel for the kernel · half-life " + root.halfLife + " h"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              PanelActionButton {
                iconText: "󰕌"
                tooltipText: "Undo last drink"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: root.last !== null
                opacity: enabled ? 1 : 0.4
                onClicked: root.undoLast()
              }
              PanelActionButton {
                iconText: "󰒓"
                tooltipText: root.settingsOpen ? "Hide settings" : "Settings"
                foreground: root.settingsOpen ? root.accent : root.foreground
                fontFamily: root.fontFamily
                onClicked: root.settingsOpen = !root.settingsOpen
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

          // ---- hero: cup + stats ----
          Item {
            width: parent.width
            height: Math.max(cup.height, stats.implicitHeight)

            CaffeineCup {
              id: cup
              width: Style.space(160)
              height: Style.space(160)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              level: root.level
              foreground: root.foreground
              urgent: root.urgent
              fontFamily: root.fontFamily
              label: root.todayPercent + "%"
              sublabel: root.todayMg + " / " + root.dailyLimitMg + " mg"
            }

            Column {
              id: stats
              anchors.left: cup.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Text {
                width: parent.width
                text: root.firstLine
                color: root.first ? root.foreground : root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: !root.first
                wrapMode: Text.WordWrap
              }

              Column {
                width: parent.width
                spacing: Style.space(3)

                StatRow {
                  label: "Today"
                  value: root.todayMg + " of " + root.dailyLimitMg + " mg · " + root.todayPercent
                    + "% · " + root.today.length + (root.today.length === 1 ? " drink" : " drinks")
                  valueColor: root.overLimit ? root.urgent : root.foreground
                }
                StatRow {
                  label: "In your system"
                  value: root.inBodyMg > 0
                    ? root.inBodyMg + " mg · gone by ~" + Model.formatTimeFrom(root.caffeineFreeAt, root.now)
                    : "0 mg · clean slate"
                }
                StatRow {
                  label: "Bedtime " + root.bedtimeLabel
                  value: Math.round(root.cutoff.atBedtime) + " mg left · limit " + root.bedtimeLimitMg + " mg"
                  valueColor: root.cutoff.atBedtime > root.bedtimeLimitMg ? root.urgent : root.foreground
                }
              }

              // Cut-off: information, not a control.
              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  text: root.cutoff.status === "clear" ? "󰒲"
                    : (root.cutoff.status === "until" ? "󰔛" : "󰅜")
                  color: root.cutoffOk ? root.accent : root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  width: parent.width - Style.space(30)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.statusLine
                  color: root.cutoffOk ? root.accent : root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  wrapMode: Text.WordWrap
                }
              }
            }
          }

          Text {
            width: parent.width
            visible: root.flash !== ""
            text: root.flash
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }

          // ---- drink grid ----
          PanelSectionHeader {
            width: parent.width
            text: "WHAT ARE YOU DRINKING?"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Grid {
            id: drinkGrid
            width: parent.width
            columns: 5
            columnSpacing: Style.space(6)
            rowSpacing: Style.space(6)
            readonly property real cellWidth: (width - columnSpacing * (columns - 1)) / columns

            Repeater {
              model: Model.PRESETS

              BorderSurface {
                required property var modelData
                readonly property bool isLast: modelData.kind === root.lastKind
                width: drinkGrid.cellWidth
                height: Style.space(66)
                radius: Style.cornerRadius
                color: isLast
                  ? Style.selectedFillFor(root.foreground, root.accent)
                  : (drinkArea.containsMouse
                    ? Style.hoverFillFor(root.foreground, root.accent)
                    : Style.normalFillFor(root.foreground, root.accent))
                borderSpec: Border.controlSpec(isLast ? "selected"
                  : (drinkArea.containsMouse ? "hover-cursor" : "normal"),
                  root.foreground, root.accent)

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)

                  DrinkIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    kind: modelData.kind
                    size: Style.space(22)
                    strokeWidth: 1.7
                    color: isLast ? root.accent : root.foreground
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.name
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: isLast
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.mg + " mg"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: drinkArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.logDrink(modelData.kind)
                }

                PanelToolTip {
                  visible: drinkArea.containsMouse
                  text: modelData.serving + " · " + modelData.mg + " mg caffeine"
                }
              }
            }
          }

          // ---- timeline ----
          PanelSectionHeader {
            width: parent.width
            text: "TIMELINE · INTAKE, HALF-LIFE AND BEDTIME"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          CaffeineGraph {
            width: parent.width
            height: Style.space(120)
            drinks: root.log.drinks
            now: root.now
            bedtime: root.cutoff.bedtime
            halfLife: root.halfLife
            bedtimeLimit: root.bedtimeLimitMg
            foreground: root.foreground
            accent: root.accent
            urgent: root.urgent
            fontFamily: root.fontFamily
          }

          // ---- today's log ----
          PanelSectionHeader {
            width: parent.width
            visible: root.today.length > 0
            text: "TODAY'S LOG"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            visible: root.today.length > 0
            spacing: Style.space(2)

            Repeater {
              model: root.today.slice().reverse()

              Item {
                required property var modelData
                width: parent.width
                height: Style.space(26)

                Row {
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(10)

                  Text {
                    width: Style.space(64)
                    text: Model.formatTime(Model.drinkTime(modelData))
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  DrinkIcon {
                    kind: modelData.kind
                    size: Style.space(18)
                    color: root.foreground
                    strokeWidth: 1.8
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: modelData.name
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

          // ---- settings ----
          PanelSectionHeader {
            width: parent.width
            visible: root.settingsOpen
            text: "ASSUMPTIONS & SETTINGS"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            visible: root.settingsOpen
            spacing: Style.space(12)

            Row {
              width: parent.width
              spacing: Style.space(16)

              NumberField {
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
                text: "Half-life used: " + root.halfLife + " h. Adults average about 5 h; moving around clears caffeine a little faster."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                width: parent.width
                wrapMode: Text.WordWrap
              }
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
                label: "At bedtime (mg)"
                value: root.bedtimeLimitMg
                from: 0
                to: 200
                stepSize: 5
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onModified: function(v) { root.saveSetting("bedtimeLimitMg", v) }
              }
            }

            Row {
              spacing: Style.space(8)
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
                value: String(root.setting("barDisplay", "Icon"))
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onChanged: function(v) { root.saveSetting("barDisplay", v) }
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

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          Text {
            width: parent.width
            text: Model.quote(root.quoteSeed)
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

  component StatRow: Item {
    property string label: ""
    property string value: ""
    property color valueColor: root.foreground
    width: parent ? parent.width : 0
    height: Math.max(labelText.implicitHeight, valueText.implicitHeight)

    Text {
      id: labelText
      width: Style.space(112)
      text: label.toUpperCase()
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.letterSpacing: 0.5
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      id: valueText
      anchors.left: labelText.right
      anchors.right: parent.right
      text: value
      color: valueColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
