class_name EventData
## ข้อมูลฝ่าย + อีเวนต์บนกระดาน (docs/faction_event_design.md) — เพิ่ม/แก้อีเวนต์ที่ไฟล์นี้ ไม่ต้องแก้โค้ด
## ตัวรันอยู่ที่ EventRunner

# ---------------------------------------------------------------- ฝ่าย
const KARMA_START := 20
const KARMA_RETURN := 10 ## อยู่ Syndicate แล้วกลับ Concord ต้อง Karma ถึงเท่านี้ (กันสลับฝ่ายไปมา)
const D_CONCORD_KARMA := 40 ## ตัวเลือก D-C ต้อง Karma เท่านี้ (Concord ระดับ 2)
const D_FREEPORT_RENOWN := 20 ## ตัวเลือก D-F ต้อง Renown เท่านี้
const FACTION_NAMES := {"concord": "Beacon Concord", "syndicate": "Redline Syndicate", "freeport": "Freeport Guild"}

# ---------------------------------------------------------------- กติกาทั่วไป
const TRAIL_SIZE := 12 ## จำทางที่เดินผ่านไว้กี่ช่อง (ถอยได้ไม่เกินนี้)
const RECENT_EVENTS := 3 ## ไม่สุ่มอีเวนต์ซ้ำกับ N อันล่าสุด
const GOLD_PCT_CAP_PER_LEVEL := 50 ## เงินจาก "X% ของเงินที่ถือ" ไม่เกิน เลเวล × ค่านี้
const CHECK_PER_STAT := 2.5 ## เช็คในอีเวนต์: โอกาส = base + (ค่าพลัง − CHECK_STAT_BASE) × ค่านี้
const CHECK_STAT_BASE := 6
const CHECK_MIN := 5.0
const CHECK_MAX := 95.0

## [รางวัลสุ่ม]: น้ำหนัก (ใบเควสยังไม่มี T-034 → นับเป็นไอเทม)
const REWARD_WEIGHTS := {"credits": 35, "consumable": 40, "gear": 25}
## tier ของอุปกรณ์รางวัลตามเลเวล: [เลเวลขั้นต่ำ, {tier: น้ำหนัก}] — ใช้แถวสุดท้ายที่เลเวลถึง
const REWARD_GEAR_TIERS := [
	[1, {"common": 100}],
	[5, {"common": 75, "rare": 25}],
	[10, {"common": 50, "rare": 40, "epic": 10}],
]
const TIER_ORDER := ["common", "rare", "epic"]

# ---------------------------------------------------------------- อีเวนต์
## options: key, label, need ("concord"/"syndicate"/"freeport"), cost, alt, effects, check, roll
##   cost    = ต้องจ่ายได้ถึงเลือกได้: ["scrip", n] / ["use_item", ชื่อ] / ["lose_gold_pct", %, ขั้นต่ำ]
##   alt     = ถ้าจ่าย cost ไม่ได้ ใช้ effects ชุดนี้แทน (ตัวเลือกยังเลือกได้)
##   check   = {"base": %, "stat": ค่าพลัง (ว่าง = ไม่ใช้), "pass": [...], "fail": [...]}
##   roll    = {"chance": %, "effects": [...]} สุ่มเกิด (ความเสี่ยง / โบนัส) ไม่ใช้ค่าพลัง
## effects: ["karma", n] ["renown", n] ["scrip", n] ["fatigue", n] ["gold_pct", %, ขั้นต่ำ] ["lose_gold_pct", %, ขั้นต่ำ]
##   ["hp_pct", %] ["reward", n, เลื่อน tier] ["item", ชื่อ] ["back", n] ["skip", n] ["steal"] ["coupon", ฝ่าย]
## weight = น้ำหนักสุ่ม (ไม่ใส่ = 10)
const EVENTS := {
	"stalled_crawler": {
		"title": "Stalled Crawler",
		"text": "A colonist waves you down. The drive coil on their cargo crawler has burnt out.",
		"options": [
			{"key": "A", "label": "Help fix it", "effects": [["fatigue", 1], ["karma", 1], ["reward", 1]]},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Loot the cargo", "effects": [["karma", -1], ["reward", 1]],
				"roll": {"chance": 25, "effects": [["skip", 1]]}},
			{"key": "D", "need": "freeport", "label": "Call a Guild mechanic", "cost": [["scrip", 5]], "effects": [["renown", 3]]},
		],
	},
	"dropped_chip": {
		"title": "Dropped Credit Chip",
		"text": "A credit chip lies in the dust, still blinking with someone's ID.",
		"options": [
			{"key": "A", "label": "Track down the owner", "effects": [["fatigue", 1]],
				"check": {"base": 60, "stat": "spd", "pass": [["karma", 1], ["gold_pct", 10, 1]], "fail": [["back", 2]]}},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Pocket it", "effects": [["karma", -1], ["reward", 1]],
				"roll": {"chance": 25, "effects": [["skip", 1]]}},
			{"key": "D", "need": "freeport", "label": "Have a Guild broker cash it", "cost": [["scrip", 1]],
				"effects": [["gold_pct", 20, 2], ["renown", 1]]},
		],
	},
	"lost_child": {
		"title": "Lost in the Mine Sector",
		"text": "A kid is crying between the ore haulers. They can't find the way home.",
		"options": [
			{"key": "A", "label": "Walk them home", "effects": [["fatigue", 1], ["karma", 1], ["reward", 1]]},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Con them out of their credits", "effects": [["karma", -1], ["gold_pct", 10, 1]],
				"roll": {"chance": 20, "effects": [["back", 3]]}},
			{"key": "D", "need": "concord", "label": "Hand them to a Beacon station",
				"effects": [["karma", 2], ["item", "Medkit"], ["coupon", "concord"]]},
		],
	},
	"suit_breach": {
		"title": "Suit Breach",
		"text": "A surveyor lies by the road, their suit hissing air.",
		"options": [
			{"key": "A", "label": "Patch them up", "cost": [["use_item", "Medkit"]],
				"effects": [["karma", 2], ["reward", 1]], "alt": [["fatigue", 2], ["skip", 1], ["karma", 2], ["reward", 1]]},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Strip their gear", "effects": [["karma", -2], ["reward", 2], ["hp_pct", -10]]},
			{"key": "D", "need": "syndicate", "label": "Sell their location to raiders", "effects": [["karma", -1], ["gold_pct", 20, 2]],
				"roll": {"chance": 30, "effects": [["steal"]]}},
		],
	},
	"crash_memorial": {
		"title": "Crash Memorial",
		"text": "A wrecked lander stands as a memorial. A donation box funds its warning beacon.",
		"options": [
			{"key": "A", "label": "Donate and pay respects", "cost": [["lose_gold_pct", 10, 1]], "effects": [["karma", 2], ["hp_pct", 20]]},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Rob the donation box", "effects": [["karma", -2], ["reward", 1]],
				"roll": {"chance": 30, "effects": [["hp_pct", -10], ["back", 2]]}},
			{"key": "D", "need": "concord", "label": "Restore the warning beacon",
				"effects": [["fatigue", 2], ["karma", 1], ["item", "Medkit"], ["hp_pct", 30]]},
		],
	},
	"rigged_scale": {
		"title": "Rigged Ore Scale",
		"text": "At the ore exchange, a trader's scale reads heavy for him and light for everyone else.",
		"options": [
			{"key": "A", "label": "Expose the hack", "effects": [["fatigue", 1]],
				"check": {"base": 55, "stat": "mag", "pass": [["karma", 1], ["renown", 1], ["reward", 1]], "fail": [["skip", 1]]}},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Blackmail the trader", "effects": [["karma", -1], ["gold_pct", 10, 1]],
				"roll": {"chance": 25, "effects": [["steal"]]}},
			{"key": "D", "need": "freeport", "label": "Let the Guild settle it", "cost": [["scrip", 2]],
				"effects": [["gold_pct", 15, 2], ["renown", 2]]},
		],
	},
	"credit_skimmer": {
		"title": "Credit Skimmer",
		"text": "Your wallet pings: someone just skimmed it. A kid with a scanner bolts into an alley.",
		"weight": 6, # อีเวนต์ร้าย ไม่มีทางเลี่ยงฟรี เกิดไม่บ่อย
		"options": [
			{"key": "A", "label": "Chase them down", "effects": [["fatigue", 1]],
				"check": {"base": 50, "stat": "spd", "pass": [["karma", 1]], "fail": [["steal"], ["back", 2]]}},
			{"key": "B", "label": "Let it go", "effects": [["lose_gold_pct", 10, 1]]},
			{"key": "C", "label": "Catch them and make them work for you", "effects": [["karma", -1], ["reward", 1]]},
			{"key": "D", "need": "syndicate", "label": "Tip off the Syndicate", "effects": [["karma", -1], ["gold_pct", 10, 1]]},
		],
	},
	"broken_span": {
		"title": "Broken Maglev Span",
		"text": "Half the maglev bridge has collapsed. Colonists are stuck on the far side.",
		"options": [
			{"key": "A", "label": "Repair it together", "effects": [["fatigue", 2], ["karma", 1], ["renown", 1]]},
			{"key": "B", "label": "Take the long way", "effects": [["back", 2]]},
			{"key": "C", "label": "Jump the gap alone",
				"check": {"base": 45, "stat": "spd", "pass": [], "fail": [["hp_pct", -15], ["steal"]]}},
			{"key": "D", "need": "freeport", "label": "Hire Guild engineers", "cost": [["scrip", 2]],
				"effects": [["renown", 2], ["gold_pct", 10, 1]]},
		],
	},
	"sealed_crate": {
		"title": "Sealed Supply Crate",
		"text": "A trader sells sealed supply crates. \"Good stuff inside,\" he says, and won't say more.",
		"options": [
			{"key": "A", "label": "Buy a crate", "cost": [["lose_gold_pct", 10, 2]], "effects": [["reward", 1, 1]]},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Grab a crate and run", "effects": [["karma", -1]],
				"check": {"base": 40, "stat": "spd", "pass": [["reward", 1]], "fail": [["skip", 1], ["lose_gold_pct", 10, 1]]}},
			{"key": "D", "need": "freeport", "label": "Use your Guild membership", "cost": [["scrip", 1]],
				"effects": [["reward", 1, 1], ["renown", 1]]},
		],
	},
	"harvest_festival": {
		"title": "Harvest Festival",
		"text": "The hydroponics dome is celebrating its harvest. They invite you in.",
		"options": [
			{"key": "A", "label": "Join in and help serve", "effects": [["fatigue", 1], ["karma", 1], ["hp_pct", 25]],
				"roll": {"chance": 30, "effects": [["reward", 1]]}},
			{"key": "B", "label": "Walk past"},
			{"key": "C", "label": "Steal food to resell", "effects": [["karma", -1], ["gold_pct", 10, 1]],
				"roll": {"chance": 30, "effects": [["back", 2]]}},
			{"key": "D", "need": "concord", "label": "Bless the harvest for the Concord",
				"effects": [["karma", 2], ["hp_pct", 25], ["item", "Medkit"], ["coupon", "concord"]]},
		],
	},
	"ion_storm": {
		"title": "Ion Storm",
		"text": "An ion storm rolls in. Static crackles across the road. You need cover, fast.",
		"weight": 6,
		"options": [
			{"key": "A", "label": "Help a stranded elder first", "effects": [["fatigue", 1], ["karma", 1], ["hp_pct", -10], ["reward", 1]]},
			{"key": "B", "label": "Find your own cover", "effects": [["skip", 1]]},
			{"key": "C", "label": "Take someone else's shelter", "effects": [["karma", -1]]},
			{"key": "D", "need": "freeport", "label": "Deploy a Guild storm dome", "cost": [["scrip", 2]],
				"effects": [["renown", 2], ["hp_pct", 10]]},
		],
	},
}
