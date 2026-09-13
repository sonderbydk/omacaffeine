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
  { kind: "monster",    name: "Monster",    mg: 160, serving: "1 can · 500 ml" }
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

// Locale short time, e.g. "23:05" or "11:05 PM".
function formatTime(date) {
  if (!date) return "—"
  try {
    return Qt.formatTime(date, Qt.locale().timeFormat(1))
  } catch (e) {
    return pad2(date.getHours()) + ":" + pad2(date.getMinutes())
  }
}

function sameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth()
    && a.getDate() === b.getDate()
}

// "11:05 PM" today, "11:05 PM tomorrow" otherwise.
function formatTimeFrom(date, now) {
  if (!date) return "—"
  var time = formatTime(date)
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

// ---- misc ------------------------------------------------------------------

function quote(seed) {
  var index = Math.abs(Math.floor(Number(seed) || 0)) % QUOTES.length
  return QUOTES[index]
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
        log.drinks.push({ t: String(d.t), kind: String(d.kind || "coffee"),
          name: String(d.name || preset(d.kind).name), mg: Number(d.mg) })
      }
    }
    if (parsed.lastKind) log.lastKind = String(parsed.lastKind)
    return log
  } catch (e) {
    return emptyLog()
  }
}

// Keep three days: enough for the decay model, small enough to stay tidy.
function pruneLog(log, now) {
  var keepFrom = now.getTime() - 3 * 24 * 3600 * 1000
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
