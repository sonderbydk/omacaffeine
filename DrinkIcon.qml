import QtQuick
import QtQuick.Shapes
import qs.Commons
import "Model.js" as Model

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


  // Each entry is a list of SVG subpaths drawn as one open outline.
  readonly property var activePaths: Model.ICON_PATHS[kind] || Model.ICON_PATHS["mug"]

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
