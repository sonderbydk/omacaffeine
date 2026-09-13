# OmaCaffeine — notes for Claude

Caffeine tracker plugin for the Omarchy bar (Quickshell/QML, no build step).
Built together with Peter on 2026-09-13 in Claude Code session
https://claude.ai/code/session_01J7aD6xrqw52FxJVhxLtJoV — that session holds
the full history of decisions; this file holds what you need to keep going.

## Layout

| File | What |
| --- | --- |
| `manifest.json` | Plugin id `io.github.sonderbydk.omacaffeine`, bar-widget entry point, settings schema (`defaults` + `schema`). Bump `version` on releases. |
| `BarWidget.qml` | Bar icon (`󰅶`) + optional mg/% label. Loads `Panel.qml`, injects `bar`, `settings`, `shell`, `anchorItem`, `hostWidget`. |
| `Panel.qml` | The drop-down: pages `main` / `settings`, stats, drink grid, timeline, today's log, IPC handler, persistence. |
| `Model.js` | Pure functions: presets, half-life model, cut-off, formatting, log (de)serialisation, headings/quotes. Test-friendly. |
| `CaffeineCup.qml` | Canvas mug that fills to `level`; overflow state past 1.0. |
| `CaffeineGraph.qml` | Pixel timeline; new/removed cells fade. |
| `DrinkIcon.qml` | Outline icons as SVG path strings in a 24×24 box, `QtQuick.Shapes`. |
| `ScrollingText.qml` | Single-line text that glides instead of wrapping. |
| `dev/harness.sh` | Standalone Quickshell window to eyeball components without the bar. |

Runtime files (not in the repo): log `~/.local/state/omacaffeine/log.json`
(three days of drinks), settings inline on the widget entry in
`~/.config/omarchy/shell.json`.

## Dev loop

The installed plugin is a separate git checkout at
`~/.config/omarchy/plugins/io.github.sonderbydk.omacaffeine` whose `origin`
is this repo. Deploy = commit here, then:

```bash
omarchy plugin update io.github.sonderbydk.omacaffeine --yes   # fast-forward pull
omarchy restart shell                                          # REQUIRED
```

Hot reload does NOT re-instantiate bar widgets, panels or services. Every QML
change needs `omarchy restart shell` before it is live. Validate the manifest
with `omarchy plugin validate .`.

Drive it without clicking:

```bash
omarchy shell io.github.sonderbydk.omacaffeine toggle | show | hide | settings
omarchy shell io.github.sonderbydk.omacaffeine log espresso     # any preset kind
omarchy shell io.github.sonderbydk.omacaffeine logLast | undo
omarchy shell io.github.sonderbydk.omacaffeine status
```

Screenshots: `grim -g "<x>,<y> <w>x<h>" out.png`; geometry from
`hyprctl clients -j` / `hyprctl layers -j` (the panel is a layer named
`omarchy-keyboard-panel`). Two monitors here: eDP-1 (laptop, scale 2) and
DP-1 (external, scale 1.5). While the user is actively working, *every* bar
panel closes right after opening, so IPC-driven panel screenshots fail; use
`dev/harness.sh` for components instead.

## Host facts learned the hard way

- Only Material Design Nerd Font glyphs (`U+F0xxx`, e.g. `󰅶 󰕌 󰒓`) render
  reliably in the bar font; Font Awesome ones (`U+F0xx`) did not.
- Third-party manifests are stripped of `__sourceDir`; resolve your own dir
  with `Qt.resolvedUrl(".")` if you ever need it.
- `shell.updateEntryInline(id, settings)` persists widget settings; the panel
  falls back to `bar.run("omarchy bar set …")`.
- Times follow the Omarchy clock widget's format (read from shell.json), not
  the system locale — the user's locale is en_US but they use a 24-hour bar.
- `qs.Commons` gives `Color`, `Style`, `Border`, `Util`; `qs.Ui` gives
  `Panel`, `KeyboardPanel`, `PanelKeyCatcher`, `BorderSurface`, `Button`,
  `PanelActionButton`, `NumberField`, `TextField`, `ButtonGroup`,
  `PanelSectionHeader`, `PanelSeparator`, `PanelToolTip`, `BarIconButton`,
  `WidgetButton`. Read them in `/usr/share/omarchy/shell/{Commons,Ui}/`.
- The first-party weather plugin
  (`/usr/share/omarchy/shell/plugins/panels/weather/`) is the reference for a
  widget + drop-down panel.

## Model assumptions (keep them honest)

First-order elimination, half-life 5 / 4.75 / 4.5 h for sitting / standing /
moving. EFSA limits: 400 mg/day (5.7 mg/kg), 200 mg per dose, 100 mg near
bedtime may affect sleep → default bedtime limit 100 mg. Cut-off for a dose
`D` with `C` mg projected at bedtime `B`, limit `L`: `t = B − h·log2(D/(L−C))`.
Not medical advice; say so in the UI.

## Style

Theme colours only (`bar.foreground`, `Color.accent`, `bar.urgent`, dimmed
foreground); the only fixed colours are the coffee in the cup. Nerdy copy is
part of the product: headings and quotes live in `Model.js`. Text that could
overflow goes in `ScrollingText`, never wraps. Baseline-align labels and
values. Commits end with the Claude co-author trailer.

## Backlog (from the owner)

- Desktop notification at cut-off and when under the bedtime limit.
- Custom drinks (name, mg, icon) and per-preset mg overrides.
- Weekly history view; click on the graph to log a drink back in time.
- Bar option showing "cut-off in 2 h 14 min".
- CSV export.
- Publish to GitHub as `sonderbydk/omacaffeine` (README already assumes it).
