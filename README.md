# OmaCaffeine

**Caffeine tracking for the Omarchy bar — because good code is written on
caffeine, and good sleep is written on knowing when to stop.**

A coffee glyph in the bar drops down a small tracker: pick what you are
drinking, watch the cup fill up towards your daily limit, and see the exact
time you should stop so the caffeine is out of your system by bedtime.

## Install

```bash
omarchy plugin add https://github.com/sonderbydk/omacaffeine.git --enable
```

Requires Omarchy 4. No extra packages.

## What it does

- **One-click logging** of Espresso, Coffee, Black Tea, Green Tea, Matcha,
  Cola, Red Bull and Monster, each with a single-colour outline icon that
  follows your theme. The most recent drink is highlighted and becomes the
  big "Log …" button; middle-click the bar icon or press Enter in the panel
  to log it again.
- **The cup.** A mug that fills with coffee as today's intake approaches the
  daily limit. Steam rises while there is caffeine in it. Past the limit the
  crema turns your theme's urgent colour.
- **Stats.** First caffeine today (or "Let's brew you some coffee — you
  deserve it!"), today's total as mg and percent with the number of drinks,
  how much is in your system right now, when you will be caffeine-free, and
  how much will still be in your blood at bedtime.
- **Cut-off.** A half-life model tells you the latest time you can have one
  more of your usual drink and still be under your bedtime limit. If that time
  has passed you get told to switch to decaf.
- **Settings** live in the panel and on the bar entry: body weight (for the
  recommended limit), typical activity (sitting, standing, moving around),
  optimal bedtime, daily limit, allowed caffeine at bedtime, and whether the
  bar shows an icon, milligrams or percent.

## The model

Caffeine follows first-order elimination: every drink decays independently
with the same half-life. The half-life depends on the activity setting
(5.5 h sitting, 5 h standing, 4.5 h moving), inside the 3 to 7 hours quoted
for healthy adults. Each drink is treated as fully absorbed when logged,
which errs on the safe side for the cut-off.

Limits follow EFSA guidance: 400 mg per day (about 5.7 mg per kg) and 200 mg
per single dose carry no safety concern for healthy adults. The bedtime limit
defaults to 50 mg. None of this is medical advice.

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
| Log a specific drink | `omarchy shell -q io.github.sonderbydk.omacaffeine log espresso` (`coffee`, `black-tea`, `green-tea`, `matcha`, `cola`, `red-bull`, `monster`) |
| Undo | `omarchy shell -q io.github.sonderbydk.omacaffeine undo` |
| Status line | `omarchy shell io.github.sonderbydk.omacaffeine status` |

A Hyprland binding for the espresso addict:

```lua
o.bind("SUPER + SHIFT + C", "Log espresso",
  "omarchy shell -q io.github.sonderbydk.omacaffeine log espresso")
```

## Files

- `~/.local/state/omacaffeine/log.json` — the drink log (last three days).
- Settings live inline on the widget's entry in `~/.config/omarchy/shell.json`
  and can be changed with `omarchy bar set io.github.sonderbydk.omacaffeine bedtime 22:30`.

MIT licensed. Brewed with Claude Code.
