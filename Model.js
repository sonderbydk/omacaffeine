.pragma library

// OmaCaffeine model: presets, the one-compartment half-life model, daily
// totals, the bedtime cut-off and locale-aware formatting. Pure functions so
// they can be unit tested and so the QML stays about layout.

// Caffeine per serving. Coffee numbers are typical café servings; a shot is
// about 63 mg, so double-shot drinks land around 125-130 mg.
var PRESETS = [
  { kind: "espresso",   name: "Espresso",   mg: 63,  serving: "1 shot · 30 ml" },
  { kind: "doppio",     name: "Doppio",     mg: 126, serving: "2 shots · 60 ml" },
  { kind: "americano",  name: "Americano",  mg: 77,  serving: "1 shot + hot water" },
  { kind: "cappuccino", name: "Cappuccino", mg: 63,  serving: "1 shot + foamed milk" },
  { kind: "latte",      name: "Latte",      mg: 126, serving: "2 shots + steamed milk" },
  { kind: "flat-white", name: "Flat White", mg: 130, serving: "2 ristretto + milk" },
  { kind: "coffee",     name: "Filter",     mg: 95,  serving: "Filter coffee · 250 ml" },
  { kind: "cold-brew",  name: "Cold Brew",  mg: 200, serving: "1 glass · 350 ml" },
  { kind: "decaf",      name: "Decaf",      mg: 3,   serving: "Decaf coffee · 250 ml" },
  { kind: "black-tea",  name: "Black Tea",  mg: 47,  serving: "1 cup · 250 ml" },
  { kind: "green-tea",  name: "Green Tea",  mg: 30,  serving: "1 cup · 250 ml" },
  { kind: "matcha",     name: "Matcha",     mg: 70,  serving: "2 g · 1 bowl" },
  { kind: "cola",       name: "Cola",       mg: 32,  serving: "1 can · 330 ml" },
  { kind: "red-bull",   name: "Red Bull",   mg: 80,  serving: "1 can · 250 ml" },
  { kind: "monster",    name: "Monster",    mg: 160, serving: "1 can · 500 ml" },
  { kind: "nitro",      name: "Nitro",      mg: 215, serving: "Nitro cold brew · 350 ml" }
]

// Every outline DrinkIcon knows, for the custom-drink icon picker: the
// presets' own icons first, then a few generic vessels.
var ICON_KINDS = [
  "espresso", "doppio", "americano", "cappuccino", "latte", "flat-white",
  "coffee", "cold-brew", "decaf", "black-tea", "green-tea", "matcha",
  "cola", "red-bull", "monster", "nitro",
  "mug", "tumbler", "bottle", "shot", "mate", "chocolate", "pill"
]

var ACTIVITIES = ["Sitting", "Standing", "Moving around"]

// Caffeine half-life in healthy adults averages about 5 hours (range roughly
// 3 to 7). Physical activity nudges clearance up a little, so a desk day
// sits at the slow end. These are assumptions, not measurements.
var HALF_LIFE_HOURS = { "Sitting": 5.0, "Standing": 4.75, "Moving around": 4.5 }

// EFSA (2015): 400 mg/day (about 5.7 mg/kg) and 200 mg (3 mg/kg) per single
// dose carry no safety concern for healthy adults; single doses of 100 mg
// close to bedtime may affect sleep in some people. That is where the
// default bedtime limit of 100 mg comes from.
var MG_PER_KG_DAY = 5.7
var MG_PER_KG_DOSE = 3
var DAILY_CAP = 400
var DEFAULT_BEDTIME_LIMIT = 100

// Headings for the drink grid. Developers deserve a hype man.
var HEADINGS = [
  "Choose your weapon, code warrior",
  "Pick your fuel, kernel hacker",
  "What powers the next commit?",
  "Select a dependency for this sprint",
  "Refuel the compiler",
  "Which beverage compiles your genius?",
  "Inject caffeine into main()",
  "Load balancer for your brain",
  "Pick a potion, wizard of the shell",
  "Fuel up, 10x developer",
  "What's brewing in your pipeline?",
  "Choose your build agent",
  "Select a runtime for greatness",
  "Deploy a beverage to production (you)",
  "Your next token generator",
  "Hydrate the neural net"
]

// Shown while a time on the graph is selected and a drink is awaited.
var BACKDATE_HEADINGS = [
  "Retroactive commit · pick the drink you forgot",
  "git rebase -i your morning · which cup was it?",
  "Time travel enabled · choose the cup",
  "Backfilling the log · what did you drink?",
  "Cherry-pick a drink into the past"
]

var WEEK_HEADINGS = [
  "Seven days of uptime",
  "Weekly sprint retrospective",
  "The week in milligrams",
  "Your caffeine changelog",
  "Last seven builds"
]

var QUOTES = [
  "Good code is written on caffeine.",
  "caffeine × tokens = production",
  "while (!asleep) { coffee++; }",
  "sudo brew install focus",
  "Half-life: about five hours. Uptime: as long as the pot lasts.",
  "Caffeine: the original hot-reload.",
  "There is no cloud, just someone else's espresso machine.",
  "Compiling thoughts… 42% · brewing dependencies.",
  "Kernel panic averted. Refill scheduled.",
  "Coffee is a language in itself. So is Rust. Both compile slowly.",
  "git commit -m \"fuelled by espresso\"",
  "One does not simply ship before the second cup.",
  "Idle CPU. Idle developer. Both need a cup.",
  "Stack overflow? Try a cup underflow first.",
  "Ctrl+C, Ctrl+V, ☕, repeat.",
  "Fable writes the code. Espresso writes the prompt.",
  "Astra plans the sprint. Caffeine runs it.",
  "Context window: 1M tokens. Attention span: one espresso.",
  "Every model has a temperature. Mine is 93 °C.",
  "Prompt engineering starts with grinding the beans.",
  "Let's cook. Preheat the developer to one flat white.",
  "Creativity is caffeine looking for a keyboard.",
  "Deep work in progress · do not decaf.",
  "Latency is just coffee that hasn't kicked in yet.",
  "The best time to brew was 5 hours ago. The second best time is now.",
  "Rate limit reached: 400 mg/day. Retry tomorrow.",
  "Zero-shot? No. Two-shot. Doppio.",
  "Pair programming: me, the model, and a pot of filter.",
  "Half-life is just exponential backoff for humans.",
  "Green tea for the review. Espresso for the merge.",
  "Work is energy over time. Coffee is energy over espresso.",
  "Your bedtime is a deadline. The half-life is the sprint.",
  "Tokens per second scale with milligrams per cup. Citation needed."
]

function preset(kind) {
  for (var i = 0; i < PRESETS.length; i++)
    if (PRESETS[i].kind === kind) return PRESETS[i]
  return PRESETS[0]
}

function isPreset(kind) {
  for (var i = 0; i < PRESETS.length; i++)
    if (PRESETS[i].kind === kind) return true
  return false
}

// ---- drinks config: custom drinks and per-preset mg overrides ---------------
//
// Lives in ~/.config/omacaffeine/drinks.json:
//   { version: 1,
//     custom: [{ kind: "custom-1694600000", name: "Batch brew", mg: 180, icon: "mug" }],
//     overrides: { espresso: 126 } }

function emptyDrinksConfig() {
  return { version: 1, custom: [], overrides: {} }
}

function parseDrinksConfig(raw) {
  var config = emptyDrinksConfig()
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object") return config
    if (Array.isArray(parsed.custom)) {
      for (var i = 0; i < parsed.custom.length; i++) {
        var c = parsed.custom[i]
        if (!c || !c.kind || !isFinite(Number(c.mg))) continue
        config.custom.push({ kind: String(c.kind), name: String(c.name || "My drink"),
          mg: Math.max(0, Math.round(Number(c.mg))),
          icon: ICON_KINDS.indexOf(String(c.icon)) >= 0 ? String(c.icon) : "mug" })
      }
    }
    if (parsed.overrides && typeof parsed.overrides === "object") {
      for (var kind in parsed.overrides) {
        var mg = Number(parsed.overrides[kind])
        if (isPreset(kind) && isFinite(mg) && mg >= 0 && Math.round(mg) !== preset(kind).mg)
          config.overrides[kind] = Math.round(mg)
      }
    }
  } catch (e) {}
  return config
}

function serializeDrinksConfig(config) {
  return JSON.stringify({ version: 1, custom: config.custom, overrides: config.overrides }, null, 2) + "\n"
}

function cloneDrinksConfig(config) {
  return parseDrinksConfig(serializeDrinksConfig(config || emptyDrinksConfig()))
}

function newCustomKind() {
  return "custom-" + Date.now().toString(36)
}

// The drink list the grid shows: presets with any mg override applied, then
// the custom drinks. Each entry carries `icon` so the grid never has to know
// which kind it is looking at.
function allDrinks(config) {
  var cfg = config || emptyDrinksConfig()
  var list = []
  for (var i = 0; i < PRESETS.length; i++) {
    var p = PRESETS[i]
    var overridden = cfg.overrides.hasOwnProperty(p.kind)
    list.push({ kind: p.kind, name: p.name, icon: p.kind, serving: p.serving,
      mg: overridden ? cfg.overrides[p.kind] : p.mg, defaultMg: p.mg,
      overridden: overridden, custom: false })
  }
  for (var c = 0; c < cfg.custom.length; c++) {
    var d = cfg.custom[c]
    list.push({ kind: d.kind, name: d.name, icon: d.icon, serving: "Your own drink",
      mg: d.mg, defaultMg: d.mg, overridden: false, custom: true })
  }
  return list
}

// Effective drink for `kind`: a preset (with override), a custom drink, or
// the first preset when the kind is unknown.
function drink(kind, config) {
  var list = allDrinks(config)
  for (var i = 0; i < list.length; i++)
    if (list[i].kind === kind) return list[i]
  return list[0]
}

function overrideCount(config) {
  var n = 0
  for (var k in (config || emptyDrinksConfig()).overrides) n++
  return n
}

// Icon to draw for a logged drink: custom drinks remember their icon on the
// log entry, presets are their own icon, unknown kinds get a plain mug.
function iconFor(entry, config) {
  if (!entry) return "mug"
  if (entry.icon && ICON_KINDS.indexOf(String(entry.icon)) >= 0) return String(entry.icon)
  if (isPreset(entry.kind)) return String(entry.kind)
  var d = drink(entry.kind, config)
  return d && d.kind === entry.kind ? d.icon : "mug"
}

function halfLifeHours(activity) {
  var value = HALF_LIFE_HOURS[String(activity || "")]
  return value ? value : HALF_LIFE_HOURS["Sitting"]
}

function recommendedDailyLimit(kg) {
  var weight = Number(kg)
  if (!isFinite(weight) || weight <= 0) return DAILY_CAP
  return Math.min(DAILY_CAP, Math.round(MG_PER_KG_DAY * weight))
}

function singleDoseLimit(kg) {
  var weight = Number(kg)
  if (!isFinite(weight) || weight <= 0) return 200
  return Math.min(200, Math.round(MG_PER_KG_DOSE * weight))
}

// ---- locale ----------------------------------------------------------------

function pad2(n) { return (n < 10 ? "0" : "") + n }

// Locale short time format, e.g. "HH:mm" or "h:mm AP".
function localeTimeFormat() {
  try {
    return Qt.locale().timeFormat(1)
  } catch (e) {
    return "HH:mm"
  }
}

// A time format derived from the Omarchy clock widget's own format string:
// anything with an AM/PM token is 12-hour, otherwise 24-hour.
function timeFormatFromClock(clockFormat) {
  var f = String(clockFormat || "")
  if (!f) return localeTimeFormat()
  return /ap/i.test(f) ? "h:mm AP" : "HH:mm"
}

// Format `date` with `fmt` (falls back to the locale short time).
function formatTime(date, fmt) {
  if (!date) return "—"
  try {
    return Qt.formatTime(date, fmt || localeTimeFormat())
  } catch (e) {
    return pad2(date.getHours()) + ":" + pad2(date.getMinutes())
  }
}

function sameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate()
}

// "11:05 PM" today, "11:05 PM tomorrow" otherwise.
function formatTimeFrom(date, now, fmt) {
  if (!date) return "—"
  var time = formatTime(date, fmt)
  if (sameDay(date, now)) return time
  var tomorrow = new Date(now.getTime() + 24 * 3600 * 1000)
  if (sameDay(date, tomorrow)) return time + " tomorrow"
  return time + " in " + Math.round((date - now) / 3600000) + " h"
}

function usesTwelveHourClock() {
  try {
    return /a/i.test(Qt.locale().timeFormat(1))
  } catch (e) {
    return false
  }
}

function usesImperialWeight() {
  try {
    return Qt.locale().measurementSystem !== 0
  } catch (e) {
    return false
  }
}

function kgToLb(kg) { return Math.round(Number(kg) * 2.20462) }
function lbToKg(lb) { return Math.round(Number(lb) / 2.20462) }

function formatTokens(n) {
  var v = Math.max(0, Number(n) || 0)
  if (v >= 1e6) return (v / 1e6).toFixed(v >= 1e7 ? 0 : 1) + "M"
  if (v >= 1e3) return (v / 1e3).toFixed(v >= 1e4 ? 0 : 1) + "k"
  return String(Math.round(v))
}

function dayLabel(date) {
  try {
    return Qt.formatDate(date, "ddd")
  } catch (e) {
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][date.getDay()]
  }
}

function formatDuration(ms) {
  var minutes = Math.max(0, Math.round(ms / 60000))
  var hours = Math.floor(minutes / 60)
  var rest = minutes % 60
  if (hours <= 0) return rest + " min"
  if (rest === 0) return hours + " h"
  return hours + " h " + rest + " min"
}

// ---- bedtime ---------------------------------------------------------------

// Accepts "23:00", "23.00", "11:00 PM", "11 pm", "11:00pm".
function parseBedtime(text) {
  var raw = String(text || "").trim()
  var match = /^(\d{1,2})(?:[:.](\d{2}))?\s*([aApP][mM]?)?\.?$/.exec(raw)
  if (!match) return null
  var h = parseInt(match[1], 10)
  var m = match[2] ? parseInt(match[2], 10) : 0
  var suffix = match[3] ? match[3].toLowerCase().charAt(0) : ""
  if (suffix === "p" && h < 12) h += 12
  if (suffix === "a" && h === 12) h = 0
  if (h > 23 || m > 59) return null
  return { hours: h, minutes: m }
}

function validBedtime(text) { return parseBedtime(text) !== null }

// Stored form is always 24-hour "HH:MM".
function normalizedBedtime(text) {
  var parsed = parseBedtime(text) || { hours: 23, minutes: 0 }
  return pad2(parsed.hours) + ":" + pad2(parsed.minutes)
}

function bedtimeAsDate(text, now) {
  var parsed = parseBedtime(text) || { hours: 23, minutes: 0 }
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(),
    parsed.hours, parsed.minutes, 0, 0)
}

// The next bedtime at or after `now`. A bedtime earlier than now today
// means tonight's has passed, so the next one is tomorrow.
function nextBedtime(now, bedtimeText) {
  var candidate = bedtimeAsDate(bedtimeText, now)
  if (candidate.getTime() <= now.getTime())
    candidate = new Date(candidate.getTime() + 24 * 3600 * 1000)
  return candidate
}

function startOfDay(now) {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0)
}

// ---- drinks ----------------------------------------------------------------

function drinkTime(drink) {
  var t = drink && drink.t ? new Date(drink.t) : null
  return t && !isNaN(t.getTime()) ? t : null
}

function todaysDrinks(drinks, now) {
  var start = startOfDay(now).getTime()
  var list = []
  for (var i = 0; i < (drinks || []).length; i++) {
    var t = drinkTime(drinks[i])
    if (t && t.getTime() >= start && t.getTime() <= now.getTime() + 60000)
      list.push(drinks[i])
  }
  list.sort(function(a, b) { return drinkTime(a) - drinkTime(b) })
  return list
}

function totalMg(list) {
  var sum = 0
  for (var i = 0; i < (list || []).length; i++) sum += Number(list[i].mg) || 0
  return Math.round(sum)
}

function firstDrink(list) {
  return list && list.length ? list[0] : null
}

function lastDrink(drinks) {
  var latest = null
  for (var i = 0; i < (drinks || []).length; i++) {
    var t = drinkTime(drinks[i])
    if (t && (!latest || t > drinkTime(latest))) latest = drinks[i]
  }
  return latest
}

// ---- pharmacokinetics --------------------------------------------------------

// One-compartment first-order elimination: every drink decays independently
// with the same half-life. Absorption is fast (30-60 min), so the model
// treats a drink as fully absorbed when logged; that errs on the safe side
// for the cut-off.
function inBody(drinks, at, halfLifeHrs) {
  var total = 0
  var hl = Math.max(0.5, Number(halfLifeHrs) || 5)
  for (var i = 0; i < (drinks || []).length; i++) {
    var t = drinkTime(drinks[i])
    if (!t) continue
    var hours = (at.getTime() - t.getTime()) / 3600000
    if (hours < 0) continue
    if (hours > 72) continue
    total += (Number(drinks[i].mg) || 0) * Math.pow(0.5, hours / hl)
  }
  return total
}

// Earliest time at or after `from` when the body level is at or below
// `limit`. Scans in five-minute steps for up to two days.
function timeUntilBelow(drinks, from, halfLifeHrs, limit) {
  var step = 5 * 60000
  var t = from.getTime()
  for (var i = 0; i < 24 * 12 * 2; i++) {
    var at = new Date(t)
    if (inBody(drinks, at, halfLifeHrs) <= limit) return at
    t += step
  }
  return new Date(t)
}

// Cut-off for one more `doseMg` today so that caffeine at bedtime stays at
// or below `limitAtBed`.
//   status "clear":  the dose fits even at bedtime
//   status "until":  the dose fits if taken before `time`
//   status "passed": the cut-off for that dose is already behind us
//   status "over":   bedtime level is already above the limit; `time` is
//                    when the body drops below it
function cutoff(drinks, now, bedtimeText, halfLifeHrs, limitAtBed, doseMg) {
  var bed = nextBedtime(now, bedtimeText)
  var hl = Math.max(0.5, Number(halfLifeHrs) || 5)
  var current = inBody(drinks, bed, hl)
  var dose = Math.max(0, Number(doseMg) || 0)
  var headroom = limitAtBed - current
  if (headroom <= 0) {
    return { status: "over", time: timeUntilBelow(drinks, bed, hl, limitAtBed),
      bedtime: bed, atBedtime: current }
  }
  if (dose <= headroom)
    return { status: "clear", time: bed, bedtime: bed, atBedtime: current }
  var hoursBefore = hl * Math.log(dose / headroom) / Math.LN2
  var latest = new Date(bed.getTime() - hoursBefore * 3600000)
  if (latest.getTime() <= now.getTime())
    return { status: "passed", time: latest, bedtime: bed, atBedtime: current }
  return { status: "until", time: latest, bedtime: bed, atBedtime: current }
}

// Body level sampled every `stepMinutes` from `from` to `to` (inclusive).
function timeline(drinks, from, to, stepMinutes, halfLifeHrs) {
  var points = []
  var step = Math.max(1, stepMinutes) * 60000
  for (var t = from.getTime(); t <= to.getTime(); t += step)
    points.push({ t: t, mg: inBody(drinks, new Date(t), halfLifeHrs) })
  return points
}

// ---- week ------------------------------------------------------------------

// One entry per calendar day, oldest first, ending today.
function dayTotals(drinks, now, days) {
  var list = []
  var todayStart = startOfDay(now)
  for (var i = days - 1; i >= 0; i--) {
    var start = new Date(todayStart.getTime() - i * 24 * 3600 * 1000)
    var end = new Date(start.getTime() + 24 * 3600 * 1000)
    var mg = 0, count = 0
    for (var d = 0; d < (drinks || []).length; d++) {
      var t = drinkTime(drinks[d])
      if (!t || t < start || t >= end) continue
      mg += Number(drinks[d].mg) || 0
      count++
    }
    list.push({ date: start, mg: Math.round(mg), count: count, label: dayLabel(start),
      isToday: i === 0 })
  }
  return list
}

// Bucket key matching tokens.py: local "YYYY-MM-DDTHH".
function hourKey(date) {
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
    + "T" + pad2(date.getHours())
}

function tokensForDay(hours, dayStart) {
  var sum = 0
  for (var h = 0; h < 24; h++)
    sum += Number((hours || {})[hourKey(new Date(dayStart.getTime() + h * 3600000))]) || 0
  return sum
}

function mean(values) {
  if (!values.length) return 0
  var sum = 0
  for (var i = 0; i < values.length; i++) sum += values[i]
  return sum / values.length
}

function pearson(xs, ys) {
  var n = Math.min(xs.length, ys.length)
  if (n < 3) return NaN
  var mx = mean(xs), my = mean(ys)
  var sxy = 0, sxx = 0, syy = 0
  for (var i = 0; i < n; i++) {
    var dx = xs[i] - mx, dy = ys[i] - my
    sxy += dx * dy; sxx += dx * dx; syy += dy * dy
  }
  if (sxx <= 0 || syy <= 0) return NaN
  return sxy / Math.sqrt(sxx * syy)
}

// Least-squares slope per step (per day when the input is daily).
function slope(values) {
  var n = values.length
  if (n < 2) return 0
  var mx = (n - 1) / 2, my = mean(values)
  var sxy = 0, sxx = 0
  for (var i = 0; i < n; i++) { sxy += (i - mx) * (values[i] - my); sxx += (i - mx) * (i - mx) }
  return sxx > 0 ? sxy / sxx : 0
}

// Every hour in the window where the agents produced tokens, paired with
// the caffeine in the body at the middle of that hour. Hours without tokens
// are left out on purpose: they say "not at the keyboard", not "no output".
function activeHours(drinks, hours, now, days, halfLifeHrs) {
  var pairs = []
  var from = startOfDay(now).getTime() - (days - 1) * 24 * 3600000
  for (var t = from; t <= now.getTime(); t += 3600000) {
    var start = new Date(t)
    var tokens = Number((hours || {})[hourKey(start)]) || 0
    if (tokens <= 0) continue
    var mg = inBody(drinks, new Date(t + 1800000), halfLifeHrs)
    pairs.push({ t: t, mg: mg, tokens: tokens })
  }
  return pairs
}

var MG_BUCKETS = [
  { label: "0–50 mg", from: 0, to: 50 },
  { label: "50–100 mg", from: 50, to: 100 },
  { label: "100–150 mg", from: 100, to: 150 },
  { label: "150–200 mg", from: 150, to: 200 },
  { label: "200+ mg", from: 200, to: Infinity }
]

// Mean tokens per active hour, grouped by how much caffeine was in the
// body. The bucket with the highest mean (and at least two hours behind
// it) is the sweet spot.
function tokenBuckets(pairs) {
  var buckets = []
  for (var b = 0; b < MG_BUCKETS.length; b++) {
    var spec = MG_BUCKETS[b]
    var values = []
    for (var i = 0; i < pairs.length; i++)
      if (pairs[i].mg >= spec.from && pairs[i].mg < spec.to) values.push(pairs[i].tokens)
    buckets.push({ label: spec.label, hours: values.length, perHour: mean(values) })
  }
  return buckets
}

function sweetSpot(buckets) {
  var best = null
  for (var i = 0; i < buckets.length; i++)
    if (buckets[i].hours >= 2 && (!best || buckets[i].perHour > best.perHour)) best = buckets[i]
  return best
}

function describeCorrelation(r, n) {
  if (isNaN(r) || n < 6) return "Not enough overlap yet · keep logging, keep prompting"
  var strength = Math.abs(r) < 0.2 ? "no real" : (Math.abs(r) < 0.5 ? "a weak" : "a solid")
  var direction = r > 0 ? "more caffeine, more tokens" : "more caffeine, fewer tokens"
  if (Math.abs(r) < 0.2) direction = "the tokens don't care about the mg"
  return "r = " + r.toFixed(2) + " over " + n + " active hours · " + strength + " link · " + direction
}

function describeTrend(perDay, unit, formatter) {
  var fmt = formatter || function(v) { return Math.round(v) }
  if (Math.abs(perDay) < 1e-9) return "flat"
  return (perDay > 0 ? "󰁝 +" : "󰁅 −") + fmt(Math.abs(perDay)) + " " + unit + "/day"
}

// ---- misc ------------------------------------------------------------------

function quote(seed) {
  var index = Math.abs(Math.floor(Number(seed) || 0)) % QUOTES.length
  return QUOTES[index]
}

function heading(seed) {
  var index = Math.abs(Math.floor(Number(seed) || 0)) % HEADINGS.length
  return HEADINGS[index]
}

function backdateHeading(seed) {
  return BACKDATE_HEADINGS[Math.abs(Math.floor(Number(seed) || 0)) % BACKDATE_HEADINGS.length]
}

function weekHeading(seed) {
  return WEEK_HEADINGS[Math.abs(Math.floor(Number(seed) || 0)) % WEEK_HEADINGS.length]
}

// Round to the nearest `minutes`, never after `now`.
function snapTime(date, now, minutes) {
  var step = Math.max(1, minutes) * 60000
  var t = Math.round(date.getTime() / step) * step
  return new Date(Math.min(t, now.getTime()))
}

// The clock widget's format string from a shell.json document, or "".
function clockFormatFromShellConfig(raw) {
  try {
    var config = JSON.parse(String(raw || ""))
    var layout = config && config.bar && config.bar.layout ? config.bar.layout : {}
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var rows = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
      for (var i = 0; i < rows.length; i++)
        if (rows[i] && rows[i].id === "omarchy.clock" && rows[i].format)
          return String(rows[i].format)
    }
  } catch (e) {}
  return ""
}

function emptyLog() {
  return { version: 1, drinks: [], lastKind: "espresso" }
}

function parseLog(raw) {
  try {
    var parsed = JSON.parse(String(raw || ""))
    if (!parsed || typeof parsed !== "object") return emptyLog()
    var log = emptyLog()
    if (Array.isArray(parsed.drinks)) {
      for (var i = 0; i < parsed.drinks.length; i++) {
        var d = parsed.drinks[i]
        if (!d || !d.t || !isFinite(Number(d.mg))) continue
        var entry = { t: String(d.t), kind: String(d.kind || "coffee"),
          name: String(d.name || preset(d.kind).name), mg: Number(d.mg) }
        if (d.icon) entry.icon = String(d.icon)
        log.drinks.push(entry)
      }
    }
    if (parsed.lastKind) log.lastKind = String(parsed.lastKind)
    return log
  } catch (e) {
    return emptyLog()
  }
}

// Keep eight days: a full week for the history page plus yesterday's tail
// for the decay model.
var KEEP_DAYS = 8
function pruneLog(log, now) {
  var keepFrom = now.getTime() - KEEP_DAYS * 24 * 3600 * 1000
  var kept = []
  for (var i = 0; i < log.drinks.length; i++) {
    var t = drinkTime(log.drinks[i])
    if (t && t.getTime() >= keepFrom) kept.push(log.drinks[i])
  }
  log.drinks = kept
  return log
}

function serializeLog(log) {
  return JSON.stringify({ version: 1, drinks: log.drinks, lastKind: log.lastKind }, null, 2) + "\n"
}
