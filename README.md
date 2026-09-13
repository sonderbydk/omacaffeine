# OmaCaffeine

**Caffeine tracking for the Omarchy bar — because good code is written on
caffeine, and good sleep is written on knowing when to stop.**

A coffee glyph in the bar drops down a small tracker: pick what you are
drinking, watch the cup fill up towards your daily limit, and see the latest
time for one more cup so the caffeine left at bedtime stays under your limit.

## Install

```bash
omarchy plugin add https://github.com/sonderbydk/omacaffeine.git --enable
```

Requires Omarchy 4. No extra packages.

## What it does

- **One-click logging** of sixteen drinks — Espresso, Doppio, Americano,
  Cappuccino, Latte, Flat White, Filter, Cold Brew, Decaf, Black Tea, Green
  Tea, Matcha, Cola, Red Bull, Monster and Nitro — each with a single-colour
  outline icon that follows your theme. The most recent drink is highlighted;
  middle-click the bar icon or press Enter in the panel to log it again.
- **Your own drinks.** The "+ Create my own" tiles take a name, the mg and
  one of 23 icons. Right-click any preset to give it your own mg ("my
  espresso is a double") and reset it to the default later; settings can
  reset every preset at once.
- **Forgot one?** Click the timeline where the cup should have been and pick
  the drink; it lands in the log at that time and the graph redraws.
- **The cup.** A mug that fills with coffee as today's intake approaches the
  daily limit, or, if you prefer, with what is in your system right now so it
  drains between cups. Empty at zero. Past the limit it goes into stack
  overflow: the crema turns your theme's urgent colour and boils.
- **Stats.** First caffeine today (or "Let's brew you some coffee — you
  deserve it!"), today's total as mg and percent with the number of drinks,
  how much is in your system right now, when you will be caffeine-free, and
  how much will still be in your blood at bedtime.
- **Cut-off.** A half-life model tells you the latest time you can have one
  more of your usual drink and still be under your bedtime limit. If that time
  has passed you get told to switch to decaf.
- **Timeline.** A pixel graph in your theme's colours: caffeine in your
  system so far, the predicted decay from now, the bedtime limit and bedtime
  itself.
- **The week.** Its own page (chart icon): seven small cups with the mg and
  cups per day, the average, the trend, and, underneath each day, the output
  tokens your coding agents produced (Claude Code and Codex transcripts on
  this machine). A second chart groups active hours by how much caffeine was
  in your system and shows the tokens per hour for each band, so you can see
  your sweet spot and the correlation. Correlation, not causation.
- **Your clock, your units.** Times follow the Omarchy clock widget's format
  (24-hour unless your clock shows AM/PM) and weight is shown in pounds for
  imperial locales.
- **Settings** on their own page (gear icon, Esc or Back returns): body
  weight (for the recommended limit), typical activity (sitting, standing,
  moving around), optimal bedtime, daily limit, allowed caffeine at bedtime,
  and whether the bar shows an icon, milligrams or percent.
- **Nerd mode is always on.** The drink grid greets you with a fresh heading
  ("Choose your weapon, code warrior"), the footer serves a pun, and past
  100 % the cup goes into stack overflow with a boiling crema.

## The model

Caffeine follows first-order elimination: every drink decays independently
with the same half-life. The half-life depends on the activity setting
(5 h sitting, 4.75 h standing, 4.5 h moving); adults average about 5 hours
with a range of roughly 3 to 7. Each drink is treated as fully absorbed when logged,
which errs on the safe side for the cut-off.

Limits follow EFSA guidance: 400 mg per day (about 5.7 mg per kg) and 200 mg
per single dose carry no safety concern for healthy adults, and 100 mg close
to bedtime may affect sleep, which is where the default bedtime limit of
100 mg comes from. Tighten it in settings if you sleep lightly. None of this
is medical advice.

For a drink of `D` mg, a bedtime `B`, half-life `h` and bedtime limit `L`,
with `C` mg already projected at bedtime from earlier drinks, the cut-off is

```
t = B - h · log2( D / (L - C) )
```

when `D > L - C`; otherwise the drink fits at any time before bed.

## Keyboard and IPC

| Action | How |
| --- | --- |
| Open / close | click the bar icon, or `omarchy shell -q io.github.sonderbydk.omacaffeine toggle` |
| Log the latest drink again | middle-click the bar icon, Enter in the panel, or `omarchy shell -q io.github.sonderbydk.omacaffeine logLast` |
| Log a specific drink | `omarchy shell -q io.github.sonderbydk.omacaffeine log espresso` (any kind from `… drinks`, custom ones included) |
| Log back in time | `omarchy shell -q io.github.sonderbydk.omacaffeine logAt espresso 09:00` |
| Undo | `omarchy shell -q io.github.sonderbydk.omacaffeine undo` |
| Week page | `omarchy shell -q io.github.sonderbydk.omacaffeine week` |
| Status line | `omarchy shell io.github.sonderbydk.omacaffeine status` |

A Hyprland binding for the espresso addict:

```lua
o.bind("SUPER + SHIFT + C", "Log espresso",
  "omarchy shell -q io.github.sonderbydk.omacaffeine log espresso")
```

## Files

- `~/.local/state/omacaffeine/log.json` — the drink log (last eight days).
- `~/.config/omacaffeine/drinks.json` — your own drinks and preset mg overrides.
- Token counts come from `~/.claude/projects/**/*.jsonl` and
  `~/.codex/sessions/**/*.jsonl`, read locally by `tokens.py`; nothing leaves
  the machine.
- Settings live inline on the widget's entry in `~/.config/omarchy/shell.json`
  and can be changed with `omarchy bar set io.github.sonderbydk.omacaffeine bedtime 22:30`.

MIT licensed. Brewed with Claude Code.
