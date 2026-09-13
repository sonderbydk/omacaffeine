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

// Outline icons as SVG subpaths in a 24x24 box, drawn by DrinkIcon.qml.
// Shared here so the ~50 icon instances do not each allocate the table.
var ICON_PATHS = {
  "espresso": [
    "M5 9 H16 V14.5 A4.5 4.5 0 0 1 11.5 19 H9.5 A4.5 4.5 0 0 1 5 14.5 Z",
    "M16 10.5 H17.5 A2.5 2.5 0 0 1 17.5 15.5 H16",
    "M3 21 H19",
    "M8 6.5 C8 5 9.5 5 9.5 3.5",
    "M11.5 6.5 C11.5 5 13 5 13 3.5"
  ],
  "doppio": [
    "M2.5 10 H11.5 V13.5 A3.5 3.5 0 0 1 8 17 H6 A3.5 3.5 0 0 1 2.5 13.5 Z",
    "M12.5 10 H21.5 V13.5 A3.5 3.5 0 0 1 18 17 H16 A3.5 3.5 0 0 1 12.5 13.5 Z",
    "M2 20.5 H22",
    "M6 7.5 C6 6 7.5 6 7.5 4.5",
    "M16 7.5 C16 6 17.5 6 17.5 4.5"
  ],
  "americano": [
    "M6 7.5 H18 L16.5 21 H7.5 Z",
    "M4.5 7.5 H19.5",
    "M6.5 4.5 H17.5 V7.5",
    "M8.5 12 C10 11 14 13 15.5 12"
  ],
  "cappuccino": [
    "M4 11 H17 V15 A4.5 4.5 0 0 1 12.5 19.5 H8.5 A4.5 4.5 0 0 1 4 15 Z",
    "M17 12.5 H18.5 A2.5 2.5 0 0 1 18.5 17.5 H17",
    "M5 11 C5 6 16 6 16 11",
    "M8 8.5 C9 7.5 12 7.5 13 8.5",
    "M3 22 H19"
  ],
  "latte": [
    "M7 4 H17 L16 21 H8 Z",
    "M7.6 10 H16.4",
    "M8.3 16 H15.7",
    "M17 6.5 H18.5 A2.5 2.5 0 0 1 18.5 11.5 H16.5"
  ],
  "flat-white": [
    "M4 10 H17 V15 A4.5 4.5 0 0 1 12.5 19.5 H8.5 A4.5 4.5 0 0 1 4 15 Z",
    "M17 11.5 H18.5 A2.5 2.5 0 0 1 18.5 16.5 H17",
    "M10.5 18 C7.5 15.5 8 13 10.5 11.5 C13 13 13.5 15.5 10.5 18 Z",
    "M10.5 11.5 V18",
    "M3 22 H19"
  ],
  "coffee": [
    "M4 8 H17 V16 A4 4 0 0 1 13 20 H8 A4 4 0 0 1 4 16 Z",
    "M17 10 H18.5 A3 3 0 0 1 18.5 16 H17",
    "M8 5.5 C8 4 9.5 4 9.5 2.5",
    "M12 5.5 C12 4 13.5 4 13.5 2.5"
  ],
  "cold-brew": [
    "M6 4 H18 L17 21 H7 Z",
    "M8.5 8 H11.5 V11 H8.5 Z",
    "M12.5 11.5 H15.5 V14.5 H12.5 Z",
    "M13.5 4 L16.5 1.5"
  ],
  "decaf": [
    "M4 10 H17 V15 A4.5 4.5 0 0 1 12.5 19.5 H8.5 A4.5 4.5 0 0 1 4 15 Z",
    "M17 11.5 H18.5 A2.5 2.5 0 0 1 18.5 16.5 H17",
    "M3 22 H19",
    "M12.5 2.5 A3.2 3.2 0 1 0 15.5 6.5 A2.4 2.4 0 0 1 12.5 2.5 Z"
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
  ],
  // Nitro: a tall can with a nitrogen widget bubble trail.
  "nitro": [
    "M8 4.5 H16 V19.5 A2 2 0 0 1 14 21.5 H10 A2 2 0 0 1 8 19.5 Z",
    "M8 4.5 C8 3 9 2.5 10 2.5 H14 C15 2.5 16 3 16 4.5",
    "M10.5 17.5 A1 1 0 1 0 10.5 15.5 A1 1 0 1 0 10.5 17.5 Z",
    "M13.5 13.5 A1 1 0 1 0 13.5 11.5 A1 1 0 1 0 13.5 13.5 Z",
    "M11 9.5 A1 1 0 1 0 11 7.5 A1 1 0 1 0 11 9.5 Z"
  ],
  // Generic vessels for custom drinks.
  "mug": [
    "M4 8 H17 V16 A4 4 0 0 1 13 20 H8 A4 4 0 0 1 4 16 Z",
    "M17 10 H18.5 A3 3 0 0 1 18.5 16 H17"
  ],
  "tumbler": [
    "M7 7 H17 L16 21 H8 Z",
    "M5.5 7 H18.5 V4.5 H5.5 Z",
    "M13.5 4.5 V2.5 H15.5",
    "M8 12 H16"
  ],
  "bottle": [
    "M10 2.5 H14 V6 C14 8 16 8.5 16 11 V20 A1.5 1.5 0 0 1 14.5 21.5 H9.5 A1.5 1.5 0 0 1 8 20 V11 C8 8.5 10 8 10 6 Z",
    "M9.5 2.5 H14.5",
    "M8 13 H16",
    "M8 17 H16"
  ],
  "shot": [
    "M8 7 H16 L14.8 20 H9.2 Z",
    "M6.5 7 H17.5",
    "M9 14 H15"
  ],
  "mate": [
    "M7 10 C5 13 5.5 20 12 20 C18.5 20 19 13 17 10 C16 8.5 8 8.5 7 10 Z",
    "M8 13.5 C10 12.5 14 12.5 16 13.5",
    "M13.5 9 L18.5 3",
    "M17 2 L20 5"
  ],
  "chocolate": [
    "M4 5 H20 V19 H4 Z",
    "M9.3 5 V19",
    "M14.6 5 V19",
    "M4 12 H20"
  ],
  "pill": [
    "M4.5 14.5 L14.5 4.5 A3.54 3.54 0 0 1 19.5 9.5 L9.5 19.5 A3.54 3.54 0 0 1 4.5 14.5 Z",
    "M9.5 9.5 L14.5 14.5"
  ]
}

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

// Strict like parseLogOrNull. Custom kinds must be unique and must not
// collide with a preset, or the grid would resolve them to the wrong drink.
function parseDrinksConfigOrNull(raw) {
  var text = String(raw || "").trim()
  if (text === "") return emptyDrinksConfig()
  var parsed
  try { parsed = JSON.parse(text) } catch (e) { return null }
  if (!parsed || typeof parsed !== "object") return null
  if (parsed.version !== undefined && parsed.version !== 1) return null
  var config = emptyDrinksConfig()
  var seen = {}
  if (Array.isArray(parsed.custom)) {
    for (var i = 0; i < parsed.custom.length; i++) {
      var c = parsed.custom[i]
      if (!c || typeof c !== "object" || !c.kind) continue
      var kind = String(c.kind)
      var mg = cleanMg(c.mg)
      if (mg === null || isPreset(kind) || seen[kind]) continue
      seen[kind] = true
      config.custom.push({ kind: kind, name: cleanName(c.name, "My drink"), mg: mg,
        icon: ICON_KINDS.indexOf(String(c.icon)) >= 0 ? String(c.icon) : "mug" })
    }
  }
  if (parsed.overrides && typeof parsed.overrides === "object") {
    for (var k in parsed.overrides) {
      var over = cleanMg(parsed.overrides[k])
      if (isPreset(k) && over !== null && over !== preset(k).mg) config.overrides[k] = over
    }
  }
  return config
}

function parseDrinksConfig(raw) {
  return parseDrinksConfigOrNull(raw) || emptyDrinksConfig()
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

// Calendar arithmetic through the Date constructor, so a day is a calendar
// day and not 24 hours: DST changes do not shift midnight or bedtime.
function addDays(date, n) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + n,
    date.getHours(), date.getMinutes(), date.getSeconds(), date.getMilliseconds())
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
  if (sameDay(date, addDays(now, 1))) return time + " tomorrow"
  return time + " in " + Math.round((date - now) / 3600000) + " h"
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


// ---- bedtime ---------------------------------------------------------------

// Accepts "23:00", "23.00", "11:00 PM", "11 pm", "11:00pm".
function parseBedtime(text) {
  var raw = String(text || "").trim()
  var match = /^(\d{1,2})(?:[:.](\d{2}))?\s*([aApP][mM]?)?\.?$/.exec(raw)
  if (!match) return null
  var h = parseInt(match[1], 10)
  var m = match[2] ? parseInt(match[2], 10) : 0
  var suffix = match[3] ? match[3].toLowerCase().charAt(0) : ""
  if (suffix && (h < 1 || h > 12)) return null
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
  if (candidate.getTime() <= now.getTime()) candidate = addDays(candidate, 1)
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

// Every drink on the calendar day containing `at`, oldest first.
function todaysDrinks(drinks, at) {
  var start = startOfDay(at).getTime()
  var end = addDays(startOfDay(at), 1).getTime()
  var list = []
  for (var i = 0; i < (drinks || []).length; i++) {
    var t = drinkTime(drinks[i])
    if (t && t.getTime() >= start && t.getTime() < end) list.push(drinks[i])
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
// `limit`. Scans in five-minute steps for up to two days; null when it is
// not reached in that window.
function timeUntilBelow(drinks, from, halfLifeHrs, limit) {
  var step = 5 * 60000
  var t = from.getTime()
  for (var i = 0; i < 24 * 12 * 2; i++) {
    var at = new Date(t)
    if (inBody(drinks, at, halfLifeHrs) <= limit) return at
    t += step
  }
  return null
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
  if (current > limitAtBed) {
    return { status: "over", time: timeUntilBelow(drinks, bed, hl, limitAtBed),
      bedtime: bed, atBedtime: current }
  }
  if (dose <= headroom)
    return { status: "clear", time: bed, bedtime: bed, atBedtime: current }
  if (headroom <= 0)
    return { status: "passed", time: bed, bedtime: bed, atBedtime: current }
  var hoursBefore = hl * Math.log(dose / headroom) / Math.LN2
  var latest = new Date(bed.getTime() - hoursBefore * 3600000)
  if (latest.getTime() <= now.getTime())
    return { status: "passed", time: latest, bedtime: bed, atBedtime: current }
  return { status: "until", time: latest, bedtime: bed, atBedtime: current }
}


// ---- week ------------------------------------------------------------------

// One entry per calendar day, oldest first, ending today.
function dayTotals(drinks, now, days) {
  var list = []
  var todayStart = startOfDay(now)
  for (var i = days - 1; i >= 0; i--) {
    var start = addDays(todayStart, -i)
    var end = addDays(start, 1)
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

// The 24 local hours of a calendar day. On a DST day one clock hour is
// missing or doubled; the key set covers whatever exists.
function hourKeysOfDay(dayStart) {
  var keys = [], seen = {}
  for (var h = 0; h < 24; h++) {
    var key = hourKey(new Date(dayStart.getFullYear(), dayStart.getMonth(), dayStart.getDate(), h))
    if (!seen[key]) { seen[key] = true; keys.push(key) }
  }
  return keys
}

// Inverse of hourKey for "YYYY-MM-DD" and "YYYY-MM-DDTHH" (local time).
function dateFromKey(key) {
  var m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}))?$/.exec(String(key || ""))
  if (!m) return new Date()
  return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), m[4] ? Number(m[4]) : 0)
}

function tokensForDay(hours, dayStart) {
  var sum = 0
  var keys = hourKeysOfDay(dayStart)
  for (var i = 0; i < keys.length; i++) sum += Number((hours || {})[keys[i]]) || 0
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
// The current, still running hour is left out too: its tokens so far
// would be averaged against full hours.
function activeHours(drinks, hours, now, days, halfLifeHrs) {
  var pairs = []
  var todayStart = startOfDay(now)
  var currentKey = hourKey(now)
  for (var i = days - 1; i >= 0; i--) {
    var day = addDays(todayStart, -i)
    for (var h = 0; h < 24; h++) {
      var start = new Date(day.getFullYear(), day.getMonth(), day.getDate(), h)
      if (start.getTime() > now.getTime()) break
      var key = hourKey(start)
      if (key === currentKey) break
      var tokens = Number((hours || {})[key]) || 0
      if (tokens <= 0) continue
      var mg = inBody(drinks, new Date(start.getTime() + 1800000), halfLifeHrs)
      pairs.push({ t: start.getTime(), mg: mg, tokens: tokens })
    }
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

// Icon glyph for a cut-off status (Material Design Nerd Font).
function cutoffIcon(status) {
  return status === "clear" ? "󰒲" : (status === "until" ? "󰔛" : "󰅜")
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

var MAX_MG = 1000
var MAX_NAME = 40

function cleanName(value, fallback) {
  var name = String(value || "").replace(/[\r\n\t]+/g, " ").trim()
  return (name || fallback).slice(0, MAX_NAME)
}

function cleanMg(value) {
  var mg = Number(value)
  if (!isFinite(mg) || mg < 0) return null
  return Math.min(MAX_MG, Math.round(mg))
}

// Strict: null for anything that is not a log we wrote (bad JSON, wrong
// shape, unknown version). An empty file is a fresh log. Entries with a
// bad time or mg are dropped individually.
function parseLogOrNull(raw) {
  var text = String(raw || "").trim()
  if (text === "") return emptyLog()
  var parsed
  try { parsed = JSON.parse(text) } catch (e) { return null }
  if (!parsed || typeof parsed !== "object" || !Array.isArray(parsed.drinks)) return null
  if (parsed.version !== undefined && parsed.version !== 1) return null
  var log = emptyLog()
  for (var i = 0; i < parsed.drinks.length; i++) {
    var d = parsed.drinks[i]
    if (!d || typeof d !== "object") continue
    var mg = cleanMg(d.mg)
    if (!drinkTime(d) || mg === null) continue
    var kind = String(d.kind || "coffee")
    var entry = { t: String(d.t), kind: kind,
      name: cleanName(d.name, isPreset(kind) ? preset(kind).name : "Drink"), mg: mg }
    if (d.icon && ICON_KINDS.indexOf(String(d.icon)) >= 0) entry.icon = String(d.icon)
    log.drinks.push(entry)
  }
  if (parsed.lastKind) log.lastKind = String(parsed.lastKind)
  return log
}

// Lenient: for cloning in-memory state, never for reading the file.
function parseLog(raw) {
  return parseLogOrNull(raw) || emptyLog()
}

// Keep eight days: a full week for the history page plus yesterday's tail
// for the decay model.
var KEEP_DAYS = 8
function pruneLog(log, now) {
  var keepFrom = now.getTime() - KEEP_DAYS * 24 * 3600 * 1000
  var keepTo = now.getTime() + 3600 * 1000   // an hour of clock skew, no more
  var kept = []
  for (var i = 0; i < log.drinks.length; i++) {
    var t = drinkTime(log.drinks[i])
    if (t && t.getTime() >= keepFrom && t.getTime() <= keepTo) kept.push(log.drinks[i])
  }
  log.drinks = kept
  return log
}

function serializeLog(log) {
  return JSON.stringify({ version: 1, drinks: log.drinks, lastKind: log.lastKind }, null, 2) + "\n"
}
