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
| `Panel.qml` | The drop-down: pages `main` / `settings` / `week` / `drink` (editor), stats, drink grid, timeline with backdating, today's log, IPC handler, persistence. |
| `Model.js` | Pure functions: presets, drinks config (custom drinks + mg overrides), half-life model, cut-off, week totals, token/caffeine analysis, formatting, log (de)serialisation, headings/quotes. Test-friendly. |
| `tokens.py` | Runtime script: output tokens per local hour from `~/.claude/projects/**/*.jsonl` (dedupe by message id) and `~/.codex/sessions/**/*.jsonl` (delta of cumulative totals). Run by a `Process` from the panel, ~0.3 s. |
| `CaffeineCup.qml` | Canvas mug that fills to `level`; `shownValue` glides (owners build the counting label from it); pour + splash on increase; overflow state past 1.0; `animated: false` for the small week cups. |
| `CaffeineGraph.qml` | Pixel timeline; new/removed cells fade. |
| `DrinkIcon.qml` | Outline icons as SVG path strings in a 24×24 box, `QtQuick.Shapes`. |
| `ScrollingText.qml` | Single-line text that glides instead of wrapping. |
| `dev/harness.sh` | Standalone Quickshell window to eyeball components without the bar. Parks its window top-left; `HARNESS_DELAY=2.4 dev/harness.sh shot.png` times the shot (the mid cup pours at 2 s, empties at 4 s). |

Runtime files (not in the repo): log `~/.local/state/omacaffeine/log.json`
(eight days of drinks; entries carry `icon` for custom drinks), custom drinks
and preset overrides in `~/.config/omacaffeine/drinks.json`
(`{custom:[{kind,name,mg,icon}], overrides:{espresso:126}}`), settings inline
on the widget entry in `~/.config/omarchy/shell.json`.

## Dev loop

The installed plugin is a separate git checkout at
`~/.config/omarchy/plugins/io.github.sonderbydk.omacaffeine` whose `origin`
is this repo. Deploy = commit here, then:

```bash
omarchy plugin update io.github.sonderbydk.omacaffeine --yes   # fast-forward pull
sleep 3     # let the shell finish its plugin hot-reload first (see below)
omarchy restart shell                                          # REQUIRED
```

`plugin update` makes the running shell hot-reload the plugin. If the
restart's exit IPC arrives while that reload is still in flight the shell
segfaults (`__dynamic_cast` in `QQmlObjectCreator::finalize`; Omarchy's
`omarchy-launch-shell` comments on this race), the supervisor starts a
replacement, and IPC sent in the next seconds hits a shell whose log file
may not be read yet. Happened once on 2026-09-13 and cost the day's log
(restored by hand). Writes are now blocked until the file has loaded, but
still wait a few seconds after `restart shell` before driving it by IPC.

Hot reload does NOT re-instantiate bar widgets, panels or services. Every QML
change needs `omarchy restart shell` before it is live. Validate the manifest
with `omarchy plugin validate .`.

Drive it without clicking:

```bash
omarchy shell io.github.sonderbydk.omacaffeine toggle | show | hide | settings
omarchy shell io.github.sonderbydk.omacaffeine log espresso     # any preset kind
omarchy shell io.github.sonderbydk.omacaffeine logAt espresso 09:00   # back in time
omarchy shell io.github.sonderbydk.omacaffeine logLast | undo
omarchy shell io.github.sonderbydk.omacaffeine status | drinks
omarchy shell io.github.sonderbydk.omacaffeine week                   # week page
omarchy shell io.github.sonderbydk.omacaffeine edit espresso | edit new   # editor page
```

The shell is started by `omarchy restart shell` as a child of the calling
shell, so its stderr lands in that command's output; QML errors show up
there (or via `qs log`). Kill stale harness windows by PID, never with
`pkill -f omacaffeine-harness` (it matches your own bash too), and the
panel layer geometry on eDP-1 is `560,1440 1440x900` for `grim -g`.

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

## The cup

Everything is one Canvas pass in `CaffeineCup.qml`: saucer shadow, liquid
(clipped to the tapered body) with wall shading, sheen, inner shadow, crema
band + bright edge + bubbles, then pour stream and splash droplets while
`pour`/`splash` are non-zero, overflow drips outside the walls, then the
outline, rim line, glaze highlight, single-stroke handle, elliptical saucer
and two-pass gradient steam. `phase` ticks at 30 fps only while visible and
steaming. Coffee colours are the one place fixed colours are allowed; the
overflow tint and the steam use the theme's urgent/foreground.

## Week page and the token analysis

Seven columns (small `CaffeineCup` with `animated: false`, mg, weekday, cups,
then a bar of the day's agent output tokens). Below: totals, trend (least
squares slope per day), then "caffeine × tokens": active hours (any tokens)
bucketed by caffeine in the body at mid-hour, mean tokens/hour per bucket,
sweet spot = best bucket with ≥ 2 hours, Pearson r over active hours. Copy
says "correlation, not causation" on purpose; keep it honest. Tokens are
refreshed at most every two minutes when the panel opens or the page shows.

## Backlog (from the owner)

- Desktop notification at cut-off and when under the bedtime limit.
- Bar option showing "cut-off in 2 h 14 min".
- CSV export.
- Publish to GitHub as `sonderbydk/omacaffeine` (README already assumes it).

Done in 0.4.0: custom drinks + per-preset mg overrides, week page with
agent tokens, click-to-backdate on the graph, flash over the cup.
