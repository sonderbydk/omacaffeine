import QtQuick
import Quickshell
import qs.Commons
import "Model.js" as Model

// Component gallery for dev/harness.sh: cups at three levels, a stat block,
// every drink icon and the timeline. Adds a drink after 1.5 s and removes it
// after 4 s so the graph fades and the cup animation can be watched.
ShellRoot {
  FloatingWindow {
    id: win
    title: "OmaCaffeine harness"
    color: Color.background
    implicitWidth: 760
    implicitHeight: 620
    visible: true

    property real lvl: 0.3
    property var drinks: [{ t: new Date(new Date().getTime() - 3 * 3600000).toISOString(),
      kind: "latte", name: "Latte", mg: 126 }]

    Timer {
      interval: 1500; running: true
      onTriggered: {
        win.drinks = win.drinks.concat([{ t: new Date().toISOString(), kind: "monster", name: "Monster", mg: 160 }])
        win.lvl = 0.9
      }
    }
    Timer {
      interval: 4000; running: true
      onTriggered: { win.drinks = win.drinks.slice(0, 1); win.lvl = 0.3 }
    }

    Column {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 14

      Row {
        spacing: 18
        CaffeineCup { width: 130; height: 130; level: 0; label: "0%"; sublabel: ""; foreground: Color.foreground; urgent: Color.urgent }
        CaffeineCup { width: 130; height: 130; level: win.lvl; label: Math.round(win.lvl * 100) + "%"; sublabel: Math.round(win.lvl * 400) + " / 400 mg"; foreground: Color.foreground; urgent: Color.urgent }
        CaffeineCup { width: 130; height: 130; level: 1.15; label: "115%"; sublabel: "stack overflow"; foreground: Color.foreground; urgent: Color.urgent }

        Column {
          width: 300
          spacing: 5
          Repeater {
            model: [
              ["Today", "477 of 400 mg · 119% · 3 drinks"],
              ["In your system", "476 mg · gone by ~16:56 tomorrow, and this one is long enough to glide"],
              ["Bedtime 23:00", "119 mg left · limit 100 mg"]
            ]
            Item {
              required property var modelData
              width: parent.width
              height: Math.max(l.implicitHeight, v.height)
              Text {
                id: l
                width: 112
                anchors.left: parent.left
                anchors.baseline: v.baseline
                text: modelData[0].toUpperCase()
                color: Qt.darker(Color.foreground, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.5
              }
              ScrollingText {
                id: v
                anchors.left: l.right
                anchors.right: parent.right
                anchors.top: parent.top
                text: modelData[1]
                color: Color.foreground
                fontFamily: Style.font.family
                pixelSize: Style.font.bodySmall
              }
            }
          }
        }
      }

      Grid {
        columns: 8
        columnSpacing: 22
        rowSpacing: 8
        Repeater {
          model: Model.PRESETS
          Column {
            required property var modelData
            spacing: 3
            DrinkIcon { anchors.horizontalCenter: parent.horizontalCenter; kind: modelData.kind; size: 36; color: Color.foreground; strokeWidth: 1.5 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: Color.foreground; font.family: Style.font.family; font.pixelSize: 11 }
          }
        }
      }

      CaffeineGraph {
        width: parent.width
        height: 120
        drinks: win.drinks
        now: new Date()
        bedtime: Model.nextBedtime(new Date(), "23:00")
        halfLife: 5
        bedtimeLimit: 100
        foreground: Color.foreground
        accent: Color.accent
        urgent: Color.urgent
        timeFormat: "HH:mm"
      }

      Text {
        width: parent.width
        text: Model.heading(3) + "  ·  " + Model.quote(7)
        color: Qt.darker(Color.foreground, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.italic: true
        wrapMode: Text.WordWrap
      }
    }
  }
}
