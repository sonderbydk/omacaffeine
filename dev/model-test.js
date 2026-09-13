// Node smoke test for Model.js: node dev/model-test.js <(sed 1d Model.js)  (run with TZ=Europe/Copenhagen for the DST cases)
global.Qt = { locale: () => ({ timeFormat: () => "HH:mm", measurementSystem: 0 }),
  formatTime: (d) => String(d.getHours()).padStart(2,"0")+":"+String(d.getMinutes()).padStart(2,"0"),
  formatDate: (d) => ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()] }
const fs = require("fs"); const vm = require("vm");
const ctx = { Qt: global.Qt, Date, Math, JSON, String, Number, Array, isFinite, isNaN, Infinity, RegExp, parseInt, console };
vm.createContext(ctx); vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), ctx);
const M = ctx; let fails = 0;
function eq(name, got, want) { const ok = JSON.stringify(got) === JSON.stringify(want); if (!ok) { fails++; console.log("FAIL", name, "got", JSON.stringify(got), "want", JSON.stringify(want)); } }
// DST (TZ=Europe/Copenhagen): Sat 2026-10-24 23:30, bedtime 23:00 -> next is Sun 23:00 local
let now = new Date(2026, 9, 24, 23, 30);
let bed = M.nextBedtime(now, "23:00"); eq("nextBedtime DST", [bed.getDate(), bed.getHours()], [25, 23]);
// dayTotals on Mon 2026-10-26 starts at local midnights
let days = M.dayTotals([], new Date(2026, 9, 26, 12), 3); eq("dayTotals starts", days.map(d => d.date.getHours()), [0,0,0]);
eq("dayTotals labels", days.map(d => d.label), ["Sat","Sun","Mon"]);
// spring forward day has 23 hour keys
eq("hourKeysOfDay spring", M.hourKeysOfDay(new Date(2026, 2, 29)).length, 23);
eq("hourKeysOfDay normal", M.hourKeysOfDay(new Date(2026, 8, 13)).length, 24);
// formatTimeFrom tomorrow across DST
eq("tomorrow", M.formatTimeFrom(new Date(2026, 9, 25, 23, 0), new Date(2026, 9, 24, 23, 30), "HH:mm"), "23:00 tomorrow");
// AM/PM validation
eq("13 PM invalid", M.parseBedtime("13 PM"), null); eq("0 AM invalid", M.parseBedtime("0 AM"), null);
eq("12 AM", M.parseBedtime("12 AM"), { hours: 0, minutes: 0 }); eq("11:30pm", M.parseBedtime("11:30pm"), { hours: 23, minutes: 30 });
eq("23:00", M.parseBedtime("23:00"), { hours: 23, minutes: 0 });
// strict parsers
eq("bad json -> null", M.parseLogOrNull("{ drinks: ["), null);
eq("empty -> empty log", M.parseLogOrNull("").drinks, []);
eq("wrong shape -> null", M.parseLogOrNull('{"version":1}'), null);
eq("future version -> null", M.parseLogOrNull('{"version":2,"drinks":[]}'), null);
let lg = M.parseLogOrNull('{"version":1,"drinks":[{"t":"2026-09-13T10:00:00Z","kind":"espresso","mg":-5},{"t":"2026-09-13T10:00:00Z","kind":"x","mg":5000,"name":"<b>hi</b>\\n"}]}');
eq("neg mg dropped, big clamped", lg.drinks.map(d => d.mg), [1000]); eq("name cleaned", lg.drinks[0].name, "<b>hi</b>");
let cfg = M.parseDrinksConfigOrNull('{"custom":[{"kind":"espresso","mg":1},{"kind":"c1","mg":10},{"kind":"c1","mg":11}],"overrides":{"espresso":63,"latte":"200"}}');
eq("custom: preset kind + dup dropped", cfg.custom.map(c => c.kind), ["c1"]); eq("override default dropped, string ok", cfg.overrides, { latte: 200 });
// cutoff with limit: current == limit -> passed, not over
let drinks = [{ t: new Date(2026, 8, 13, 12, 0).toISOString(), kind: "espresso", mg: 100 }];
now = new Date(2026, 8, 13, 13, 0);
let atBed = M.inBody(drinks, M.nextBedtime(now, "23:00"), 5);
let c = M.cutoff(drinks, now, "23:00", 5, Math.round(atBed * 1000) / 1000 + 1e-9, 63);
eq("headroom ~0 -> passed", c.status, "passed");
eq("no drinks, limit 5, 63 mg needs 18 h -> passed", M.cutoff([], now, "23:00", 5, 5, 63).status, "passed");
eq("timeUntilBelow unreachable -> null", M.timeUntilBelow([{ t: now.toISOString(), kind: "x", mg: 100000 }], now, 5, 5), null);
// todaysDrinks: whole day, including later today
eq("todaysDrinks includes later today", M.todaysDrinks([{ t: new Date(2026, 8, 13, 20).toISOString(), mg: 1 }], new Date(2026, 8, 13, 9)).length, 1);
// pruneLog drops far-future
eq("prune future", M.pruneLog({ drinks: [{ t: new Date(Date.now() + 5 * 3600000).toISOString(), mg: 1 }] }, new Date()).drinks.length, 0);
eq("dateFromKey", M.dateFromKey("2026-09-13T09").getHours(), 9);
// activeHours skips current hour
let hrs = {}; hrs[M.hourKey(new Date(2026, 8, 13, 9))] = 10; hrs[M.hourKey(new Date(2026, 8, 13, 10))] = 20;
eq("activeHours excludes current", M.activeHours([], hrs, new Date(2026, 8, 13, 10, 30), 7, 5).map(p => p.tokens), [10]);
console.log(fails ? `${fails} FAILED` : "all model tests passed");
process.exit(fails ? 1 : 0);
