import QtQuick
import QtQuick.Shapes
import qs.Commons

// Single-colour outline illustration for a drink preset. Paths are drawn in
// a 24x24 box and scaled to `size`, so the stroke stays crisp at any size.
Item {
  id: root

  property string kind: "coffee"
  property real size: Style.space(28)
  property color color: Color.foreground
  property real strokeWidth: 1.6

  width: size
  height: size

  // Each entry is a list of SVG path strings drawn as open outlines.
  readonly property var paths: ({
    "espresso": [
      "M5 9 H16 V14.5 A4.5 4.5 0 0 1 11.5 19 H9.5 A4.5 4.5 0 0 1 5 14.5 Z",
      "M16 10.5 H17.5 A2.5 2.5 0 0 1 17.5 15.5 H16",
      "M3 21 H19",
      "M8 6.5 C8 5 9.5 5 9.5 3.5",
      "M11.5 6.5 C11.5 5 13 5 13 3.5"
    ],
    "coffee": [
      "M4 8 H17 V16 A4 4 0 0 1 13 20 H8 A4 4 0 0 1 4 16 Z",
      "M17 10 H18.5 A3 3 0 0 1 18.5 16 H17",
      "M8 5.5 C8 4 9.5 4 9.5 2.5",
      "M12 5.5 C12 4 13.5 4 13.5 2.5"
    ],
    "black-tea": [
      "M4 10 H17 V15 A4.5 4.5 0 0 1 12.5 19.5 H8.5 A4.5 4.5 0 0 1 4 15 Z",
      "M17 11.5 H18.5 A2.5 2.5 0 0 1 18.5 16.5 H17",
      "M3 22 H19",
      "M13 10 L15.5 4.5 H19",
      "M19 3 H21 V6 H19 Z"
    ],
    "green-tea": [
      "M5 9 H19 L17.5 18 A2.5 2.5 0 0 1 15 20 H9 A2.5 2.5 0 0 1 6.5 18 Z",
      "M8 9 C8 6 11 5 12 3.5 C13 5 16 6 16 9",
      "M12 3.5 V9"
    ],
    "matcha": [
      "M3.5 11 H20.5 C20.5 16 17 20 12 20 C7 20 3.5 16 3.5 11 Z",
      "M15 11 V4.5 M13.5 4.5 H16.5",
      "M15 4.5 L12.5 9 M15 4.5 L15 9 M15 4.5 L17.5 9",
      "M6 13 C8 12 10 12 12 13"
    ],
    "cola": [
      "M9.5 2.5 H14.5 V5.5 L16.5 9 V19.5 A2 2 0 0 1 14.5 21.5 H9.5 A2 2 0 0 1 7.5 19.5 V9 L9.5 5.5 Z",
      "M8.5 2.5 H15.5",
      "M7.5 12 C10 11 14 13 16.5 12",
      "M7.5 15 C10 14 14 16 16.5 15"
    ],
    "red-bull": [
      "M8 4.5 H16 V19.5 A2 2 0 0 1 14 21.5 H10 A2 2 0 0 1 8 19.5 Z",
      "M8 4.5 C8 3 9 2.5 10 2.5 H14 C15 2.5 16 3 16 4.5",
      "M10.5 9 L13.5 12 L10.5 15",
      "M8 17.5 H16"
    ],
    "monster": [
      "M7 4.5 H17 V19.5 A2 2 0 0 1 15 21.5 H9 A2 2 0 0 1 7 19.5 Z",
      "M7 4.5 C7 3 8 2.5 9 2.5 H15 C16 2.5 17 3 17 4.5",
      "M9 8 L10.5 16",
      "M12 7 L12.5 16.5",
      "M15 8 L14 16"
    ]
  })

  readonly property var activePaths: paths[kind] || paths["coffee"]

  Shape {
    id: shape
    width: 24
    height: 24
    scale: root.size / 24
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    antialiasing: true

    // One ShapePath: an SVG path string may hold several subpaths.
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeWidth
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.activePaths.join(" ") }
    }
  }
}
