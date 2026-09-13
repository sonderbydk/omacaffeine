.pragma library

// OmaCaffeine model: presets, the one-compartment half-life model, daily
// totals and the bedtime cut-off. Pure functions so they can be unit tested
// and so the QML stays about layout.

var PRESETS = [
  { kind: "espresso",  name: "Espresso",  mg: 63,  serving: "1 shot · 30 ml" },
  { kind: "coffee",    name: "Coffee",    mg: 95,  serving: "1 cup · 250 ml" },
  { kind: "black-tea", name: "Black Tea", mg: 47,  serving: "1 cup · 250 ml" },
  { kind: "green-tea", name: "Green Tea", mg: 30,  serving: "1 cup · 250 ml" },
  { kind: "matcha",    name: "Matcha",    mg: 70,  serving: "2 g · 1 bowl" },
  { kind: "cola",      name: "Cola",      mg: 32,  serving: "1 can · 330 ml" },
  { kind: "red-bull",  name: "Red Bull",  mg: 80,  serving: "1 can · 250 ml" },
  { kind: "monster",   name: "Monster",   mg: 160, serving: "1 can · 500 ml" }
]

var ACTIVITIES = ["Sitting", "Standing", "Moving around"]

// Caffeine half-life in adults is usually quoted as 3 to 7 hours. Physical
// activity nudges clearance up a little, so a desk day sits at the slow end.
var HALF_LIFE_HOURS = { "Sitting": 5.5, "Standing": 5.0, "Moving around": 4.5 }

// EFSA guidance: 400 mg/day (about 5.7 mg/kg) and 200 mg (3 mg/kg) per dose
// carry no safety concern for healthy adults.
var MG_PER_KG_DAY = 5.7
var MG_PER_KG_DOSE = 3
var DAILY_CAP = 400

var QUOTES = [
  "Good code is written on caffeine.",
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
  "Ctrl+C, Ctrl+V, ☕, repeat."
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

function pad2(n) { return (n < 10 ? "0" : "") + n }

function formatTime(date) {
  if (!date) return "—"
  return pad2(date.getHours()) + ":" + pad2(date.getMinutes())
}

// "12:31" today, "12:31 tomorrow" otherwise.
function formatTimeFrom(date, now) {
  if (!date) return "—"
  var time = formatTime(date)
  var sameDay = date.getFullYear() === now.getFullYear()
    && date.getMonth() === now.getMonth() && date.getDate() === now.getDate()
  if (sameDay) return time
  var tomorrow = new Date(now.getTime() + 24 * 3600 * 1000)
  var isTomorrow = date.getFullYear() === tomorrow.getFullYear()
    && date.getMonth() === tomorrow.getMonth() && date.getDate() === tomorrow.getDate()
  return time + (isTomorrow ? " tomorrow" : " in " + Math.round((date - now) / 3600000) + " h")
}

function formatDuration(ms) {
  var minutes = Math.max(0, Math.round(ms / 60000))
  var hours = Math.floor(minutes / 60)
  var rest = minutes % 60
  if (hours <= 0) return rest + " min"
  if (rest === 0) return hours + " h"
  return hours + " h " + rest + " min"
}

function parseBedtime(text) {
  var match = /^\s*(\d{1,2})[:.](\d{2})\s*$/.exec(String(text || ""))
  if (!match) return { hours: 23, minutes: 0 }
  var h = Math.min(23, Math.max(0, parseInt(match[1], 10)))
  var m = Math.min(59, Math.max(0, parseInt(match[2], 10)))
  return { hours: h, minutes: m }
}

function validBedtime(text) {
  return /^\s*([01]?\d|2[0-3])[:.]([0-5]\d)\s*$/.test(String(text || ""))
}

function normalizedBedtime(text) {
  var parsed = parseBedtime(text)
  return pad2(parsed.hours) + ":" + pad2(parsed.minutes)
}

// The next bedtime at or after `now`. A bedtime earlier than now today
// means tonight's has passed, so the next one is tomorrow.
function nextBedtime(now, bedtimeText) {
  var parsed = parseBedtime(bedtimeText)
  var candidate = new Date(now.getFullYear(), now.getMonth(), now.getDate(),
    parsed.hours, parsed.minutes, 0, 0)
  if (candidate.getTime() <= now.getTime())
    candidate = new Date(candidate.getTime() + 24 * 3600 * 1000)
  return candidate
}

function startOfDay(now) {
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0)
}

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
