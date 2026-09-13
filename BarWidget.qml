import QtQuick
import qs.Commons
import qs.Ui

// OmaCaffeine bar widget: a coffee glyph (optionally with today's total)
// that drops the tracker panel down from the bar.
BarWidget {
  id: root
  moduleName: "io.github.sonderbydk.omacaffeine"

  // Host-injected facade; used to persist settings edited inside the panel.
  property var shell: null

  readonly property var panel: panelLoader.item
  readonly property string display: String(setting("barDisplay", "Icon"))
  readonly property string barText: {
    if (!panel) return ""
    if (display === "Milligrams") return panel.todayMg + " mg"
    if (display === "Percent") return panel.todayPercent + "%"
    return ""
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("shell" in target) target.shell = root.shell
    if ("moduleName" in target) target.moduleName = root.moduleName
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panel && panel.toggle) panel.toggle()
  }

  // Shape contract for shell.summon/hide/toggle routing.
  readonly property bool opened: panel ? panel.opened === true : false
  function open() { if (panel && panel.openFromHotkey) panel.openFromHotkey() }
  function close() { if (panel && panel.close) panel.close() }
  readonly property bool popoutSwitchClosing: panel ? panel.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panel) panel.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth + (label.visible ? label.implicitWidth : 0)
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onShellChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: implicitWidth
    bar: root.bar
    text: "󰅶"
    slotSize: Style.bar.statusSlot
    tooltipText: root.panel
      ? (root.panel.todayMg + " mg today · " + root.panel.statusLine)
      : "OmaCaffeine"
    onPressed: function(b) {
      if (b === Qt.MiddleButton && root.panel) root.panel.logLast()
      else root.togglePanel()
    }
  }

  WidgetButton {
    id: label
    anchors.left: button.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: visible ? implicitWidth : 0
    visible: root.barText !== ""
    bar: root.bar
    text: root.barText
    fontSize: Style.font.bodySmall
    active: root.panel ? root.panel.overLimit : false
    onPressed: function(b) { root.togglePanel() }
  }
}
