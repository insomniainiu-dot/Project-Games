class_name GameData
## ข้อมูลเกมทั้งหมด (อาชีพ / ไอเทม / มอนสเตอร์ / ช่องกระดาน / เมือง)
## เพิ่ม-แก้ของในเกมได้ที่ไฟล์นี้ไฟล์เดียว ไม่ต้องแตะโค้ดส่วนอื่น

# ---------------------------------------------------------------- อาชีพ (ธีม Sci-Fi, ดู docs/class_passive_design.md)
# base = ค่าเริ่มต้นที่ Lv1, grow = ค่าที่เพิ่มต่อเลเวล
# gold_mult (ไม่ใส่ = 1.0): ตัวคูณเงินจากช่องกระดานและมอนสเตอร์ (ระบบ board_perk เต็มอยู่ใน T-067)
# ท่าประจำอาชีพอยู่ที่ CCBalance.JOB_SKILL
# suggested = ลำดับโหนด Passive Tree ที่แนะนำ (ปุ่ม "Suggested" ในหน้า Passive) — จุดเริ่มของต้นดูที่ PassiveTree.NODES (job)
const JOBS := {
	"Vanguard": {
		"desc": "Frontline tank. Hits hard, takes hits.",
		"base": {"hp": 34, "atk": 9, "def": 8, "mag": 2, "spd": 5, "lck": 4},
		"grow": {"hp": 7, "atk": 3, "def": 2, "mag": 0, "spd": 1, "lck": 0},
		"suggested": ["assault_l", "reinforced_plating", "assault_r", "adrenal_surge", "assault_out", "breacher", "assault_in", "hub"],
	},
	"Marksman": {
		"desc": "Sharpshooter. High firepower and critical hits.",
		"base": {"hp": 28, "atk": 8, "def": 4, "mag": 3, "spd": 5, "lck": 8},
		"grow": {"hp": 5, "atk": 2, "def": 1, "mag": 0, "spd": 1, "lck": 2},
		"suggested": ["precision_r", "weak_point", "precision_l", "steady_aim", "precision_out", "quick_draw", "precision_in", "hub"],
	},
	"Engineer": {
		"desc": "Drone builder. Solid tech and armor.",
		"base": {"hp": 30, "atk": 5, "def": 7, "mag": 9, "spd": 4, "lck": 3},
		"grow": {"hp": 6, "atk": 1, "def": 2, "mag": 2, "spd": 1, "lck": 0},
		"suggested": ["machine_l", "overclocked_drones", "machine_r", "auto_repair", "machine_out", "kinetic_barrier", "machine_in", "hub"],
	},
	"Psion": {
		"desc": "Psychic. Huge tech power, fragile body.",
		"base": {"hp": 26, "atk": 4, "def": 4, "mag": 11, "spd": 5, "lck": 4},
		"grow": {"hp": 5, "atk": 0, "def": 1, "mag": 3, "spd": 1, "lck": 1},
		"suggested": ["psi_l", "deep_focus", "psi_r", "plasma_feed", "psi_out", "psi_shield", "psi_in", "hub"],
	},
	"Infiltrator": {
		"desc": "Fast and sneaky. Finds extra credits.",
		"base": {"hp": 28, "atk": 6, "def": 4, "mag": 3, "spd": 9, "lck": 6},
		"grow": {"hp": 5, "atk": 1, "def": 1, "mag": 0, "spd": 3, "lck": 1},
		"suggested": ["shadow_l", "light_step", "shadow_r", "pickpocket", "shadow_out", "second_chance", "shadow_in", "hub"],
		"gold_mult": 1.25,
	},
}
const START_JOB := "Psion"
const FREE_RESET_LEVEL := 5 # รีเซ็ต Passive Tree ฟรีถึงเลเวลนี้
const RESET_COST_PER_LEVEL := 10 # หลังจากนั้นเสีย 10 × เลเวล

# ชื่อค่าพลังที่ผู้เล่นเห็น (คีย์ในโค้ดยังเป็น hp/atk/def/mag/spd) · lck = อัตราคริ (CCBalance.CRIT_PER_LCK)
const STAT_LABELS := {"hp": "HP", "atk": "ATK", "def": "ARM", "mag": "TEC", "spd": "SPD", "lck": "LCK"}


static func stat_label(key: String) -> String:
	return STAT_LABELS.get(key, key.to_upper())

# ---------------------------------------------------------------- ไอเทม
# type: "use" = ใช้แล้วหมดไป, "weapon"/"armor"/"accessory" = อุปกรณ์สวมใส่
# battle (ไอเทมใช้แล้วหมด): ใช้ในการต่อสู้ได้ตอนไหน "attack" = เทิร์นบุก, "defense" = เทิร์นป้องกัน, "any" = ทั้งสอง
#   ผลในการต่อสู้: heal / buff {สเตตัส: +ค่า} (ตลอดการต่อสู้นั้น) / damage (โดนแน่นอน) / poison {turns, damage} / escape
# die_body / die_rune (ไม่ใส่ก็ได้): ใน Dice Duel เต๋าลูกของช่องนั้น (อาวุธ=ลูก 1, เกราะ=ลูก 2, เครื่องประดับ=ลูก 3) ได้ Body/Rune นี้
const ITEMS := {
	"Herb": {"type": "use", "battle": "defense", "price": 15, "heal": 20, "desc": "Heal 20 HP. (Battle: defense turn)"},
	"Big Herb": {"type": "use", "battle": "defense", "price": 40, "heal": 60, "desc": "Heal 60 HP. (Battle: defense turn)"},
	"Power Tonic": {"type": "use", "battle": "defense", "price": 45, "buff": {"atk": 4, "mag": 4}, "desc": "ATK and TEC +4 for this battle. (Battle: defense turn)"},
	"Iron Tonic": {"type": "use", "battle": "defense", "price": 40, "buff": {"def": 5}, "desc": "ARM +5 for this battle. (Battle: defense turn)"},
	"Fire Bomb": {"type": "use", "battle": "attack", "price": 35, "damage": 12, "desc": "Deal 12 damage, never misses. (Battle: attack turn)"},
	"Poison Dart": {"type": "use", "battle": "attack", "price": 30, "poison": {"turns": 3, "damage": 4}, "desc": "Poison: 4 damage for 3 turns. (Battle: attack turn)"},
	"Smoke Ball": {"type": "use", "battle": "any", "price": 25, "escape": true, "desc": "Escape a battle for sure. (Battle: any turn)"},
	# อาวุธ — weapon_type กำหนดท่า Attack (CCBalance.WEAPON_TYPES)
	"Oak Staff": {"type": "weapon", "weapon_type": "melee", "price": 0, "atk": 1, "mag": 2, "desc": "A plain staff."},
	"Moon Rod": {"type": "weapon", "weapon_type": "rod", "price": 90, "atk": 2, "mag": 6, "desc": "A rod that glows under the moon."},
	"Iron Blade": {"type": "weapon", "weapon_type": "melee", "price": 110, "atk": 6, "desc": "A sturdy iron sword."},
	"Hunter Bow": {"type": "weapon", "weapon_type": "bow", "price": 150, "atk": 5, "spd": 3, "die_body": "quick", "desc": "Light and quick. (Quick die)"},
	"Sun Staff": {"type": "weapon", "weapon_type": "rod", "price": 220, "atk": 3, "mag": 10, "die_rune": "spark", "desc": "Burns with solar magic. (Spark rune)"},
	"War Axe": {"type": "weapon", "weapon_type": "heavy", "price": 260, "atk": 11, "spd": -1, "die_body": "heavy", "desc": "Heavy, but hits like a cart. (Heavy die)"},
	# อาวุธ Unique: ค่าตายตัว มีข้อดี + ข้อเสีย — ไม่ขายในร้าน ได้จากมอนสเตอร์ (MONSTERS "unique_chance")
	#   mods = ผลพิเศษ (คีย์เดียวกับ PassiveTree mods รวมด้วย CCBalance.merge_mods)
	#   grants = ท่าติดอาวุธ (ใช้ได้เลยโดยไม่กินช่อง gem) · pros / cons = ข้อความที่ผู้เล่นเห็น
	"Voidreaver": {"type": "weapon", "weapon_type": "heavy", "rarity": "unique", "price": 400, "atk": 12, "spd": -4,
		"mods": {"attack_mult": 1.2, "no_dodge": true},
		"pros": ["Attack damage x1.2"], "cons": ["You can't Dodge", "SPD -4"], "desc": "A hull-cutter ripped off a derelict warship."},
	"Siphon Edge": {"type": "weapon", "weapon_type": "melee", "rarity": "unique", "price": 400, "atk": 8, "lck": 3,
		"mods": {"stat_pct.hp": -15}, "grants": "blood_siphon",
		"pros": ["Grants Blood Siphon: heals 50% of the damage it deals"], "cons": ["Max HP -15%"], "desc": "The blade drinks. So do you."},
	"Singularity Rod": {"type": "weapon", "weapon_type": "rod", "rarity": "unique", "price": 450, "atk": 2, "mag": 12,
		"mods": {"imperfect_mult": 0.8}, "grants": "singularity",
		"pros": ["Grants Singularity: 4 slots, TEC x2.4, Perfect ignores resist + stuns"], "cons": ["Singularity costs 2 Focus and 10% max HP", "Every non-Perfect hit deals x0.8"],
		"desc": "A pocket black hole on a stick. Handle with care."},
	"Ricochet Repeater": {"type": "weapon", "weapon_type": "bow", "rarity": "unique", "price": 400, "atk": 6, "spd": 4, "lck": 4, "def": -3,
		"grants": "ricochet",
		"pros": ["Grants Ricochet: 3 slots, SPD check, Perfect hits twice", "SPD +4, LCK +4"], "cons": ["ARM -3"], "desc": "Every shot finds a second target. Usually the same one."},
	"Warden's Bulwark": {"type": "weapon", "weapon_type": "melee", "rarity": "unique", "price": 400, "atk": 3, "def": 6, "hp": 15,
		"mods": {"start_barrier": 10, "guard_heal_pct": 8, "attack_mult": 0.7},
		"pros": ["Start each battle with a 10 Barrier", "Guard heals 8% max HP", "ARM +6, HP +15"], "cons": ["Attack damage x0.7"], "desc": "A riot shield with a stun baton bolted on."},
	# ชุดเกราะ
	"Travel Cloak": {"type": "armor", "price": 0, "def": 1, "desc": "A worn cloak."},
	"Leather Vest": {"type": "armor", "price": 70, "def": 4, "desc": "Simple leather protection."},
	"Rune Robe": {"type": "armor", "price": 120, "def": 3, "mag": 3, "spd": 1, "desc": "Stitched with runes."},
	"Chain Mail": {"type": "armor", "price": 180, "def": 8, "spd": -1, "desc": "Linked steel rings."},
	"Knight Plate": {"type": "armor", "price": 300, "hp": 10, "def": 13, "spd": -2, "die_body": "heavy", "desc": "Full plate of a royal knight. (Heavy die)"},
	# เครื่องประดับ
	"Lucky Charm": {"type": "accessory", "price": 60, "spd": 1, "lck": 5, "desc": "A four-leaf clover in glass."},
	"Power Ring": {"type": "accessory", "price": 100, "atk": 3, "desc": "Makes your grip stronger."},
	"Life Pendant": {"type": "accessory", "price": 120, "hp": 15, "desc": "Warm to the touch."},
	"Sage Earring": {"type": "accessory", "price": 140, "mag": 4, "die_rune": "twin", "desc": "Whispers old spells. (Twin rune)"},
}

const ITEM_SHOP_STOCK := ["Herb", "Big Herb", "Power Tonic", "Iron Tonic", "Fire Bomb", "Poison Dart", "Smoke Ball"] # ร้านไอเทม (ช่อง Shop)
# ร้านอาวุธ (บ้านข้างปราสาท / ช่อง Smithy) แยกตามหมวด
const SMITHY_STOCK := {
	"weapon": ["Moon Rod", "Iron Blade", "Hunter Bow", "Sun Staff", "War Axe"],
	"armor": ["Leather Vest", "Rune Robe", "Chain Mail", "Knight Plate"],
	"accessory": ["Lucky Charm", "Power Ring", "Life Pendant", "Sage Earring"],
}
const SLOT_NAMES := {"weapon": "Weapon", "armor": "Armor", "accessory": "Accessory"}
const STAT_KEYS := ["hp", "atk", "def", "mag", "spd", "lck"]
const MAX_ITEMS := 6
const MAX_GEAR := 8 # อุปกรณ์สำรอง (ที่ยังไม่ได้สวม) เก็บได้กี่ชิ้น
const SELL_RATE := 0.5 # ขายคืนได้ครึ่งราคา


## ข้อมูลไอเทม (ชื่อในร้าน หรือ instance id ของ Rare/Epic "ชื่อฐาน#เลข") — อุปกรณ์ให้ใช้ตัวนี้แทน ITEMS[...]
static func item(id: String) -> Dictionary:
	return ItemDB.data(id)


## ข้อความค่าพลังของอุปกรณ์ เช่น "ATK+6 SPD-1" (รวม affix แล้ว)
static func stat_text(item_id: String) -> String:
	var d := item(item_id)
	var parts := PackedStringArray()
	for k in STAT_KEYS:
		var v: int = d.get(k, 0)
		if v != 0:
			parts.append("%s%+d" % [stat_label(k), v])
	return " ".join(parts)


static func sell_price(item_id: String) -> int:
	return int(item(item_id).price * SELL_RATE)


## ประเภทอาวุธของไอเทม ("" = ไม่ใช่อาวุธ)
static func weapon_type(item_id: String) -> String:
	var d := item(item_id)
	if d.get("type", "") != "weapon":
		return ""
	return d.get("weapon_type", CCBalance.DEFAULT_WEAPON_TYPE)


## คำอธิบายท่า Attack ของอาวุธ เช่น "Attack: Cleave (4 slots, ATK)"
static func weapon_attack_text(item_id: String) -> String:
	var wt := weapon_type(item_id)
	if wt == "":
		return ""
	var a := CCBalance.weapon_attack(wt)
	return "Attack: %s (%d slots, %s%s)" % [a.name, a.slots, stat_label(a.check), ", tech" if a.kind == "magic" else ""]


static func gem_name(gem: String) -> String:
	return CCBalance.ACTIONS[gem].name


## "common" / "rare" / "epic" / "unique" (ดู ItemDB.TIERS)
static func rarity(item_id: String) -> String:
	return item(item_id).get("rarity", "common")


static func unique_items() -> Array:
	return ITEMS.keys().filter(func(it): return rarity(it) == "unique")


## ชื่อที่แสดง: Unique = "★ ชื่อ", Rare/Epic = "◆ ชื่อฐาน (Rare)"
static func display_name(item_id: String) -> String:
	match rarity(item_id):
		"unique":
			return "★ " + item_id
		"rare", "epic":
			return "◆ %s (%s)" % [ItemDB.base_of(item_id), ItemDB.TIERS[rarity(item_id)].name]
	return item_id


## รายละเอียดพิเศษทีละบรรทัด: Unique = ข้อดี (+) / ข้อเสีย (-), Rare/Epic = affix ("" = ไม่มี)
static func item_lines(item_id: String) -> String:
	var lines := PackedStringArray()
	if rarity(item_id) == "unique":
		var d := item(item_id)
		for p in d.get("pros", []):
			lines.append("+ " + p)
		for c in d.get("cons", []):
			lines.append("- " + c)
	else:
		for a in ItemDB.affix_lines(item_id):
			lines.append("+ " + a)
	return "\n".join(lines)

# ---------------------------------------------------------------- มอนสเตอร์
# sprite: ไฟล์สไปรต์ชีต (แถว 0 = หันหน้า, แถว 1 = หันซ้าย), frames = จำนวนเฟรมต่อแถว
# cc_actions: ท่าของมอนสเตอร์ในระบบต่อสู้ช่องเช็ค {ท่า: น้ำหนักการสุ่ม} (ท่าดูใน CCBalance.ACTIONS, "guard" = ตั้งการ์ด)
# cc_defense: วิธีป้องกันของมอนสเตอร์ตอนโดนโจมตี {block/dodge/counter: น้ำหนักการสุ่ม}
# unique_chance: โอกาสดรอปอาวุธ Unique ที่ยังไม่มีเมื่อชนะ (ไม่ใส่ = UNIQUE_DROP_CHANCE)
# gear_chance: โอกาสดรอปอุปกรณ์ Rare/Epic เมื่อชนะ (ไม่ใส่ = ItemDB.GEAR_DROP_CHANCE)
# dd_job / dd_personality: อาชีพ (สกิล) และนิสัย AI ในระบบต่อสู้ Dice Duel (เก็บไว้ ยังไม่ได้ใช้)
# offense/defense: น้ำหนักการสุ่มท่าของระบบต่อสู้เดิม (battle.gd) — Dice Duel ไม่ใช้แล้ว
const MONSTERS := {
	"Skeleton": {
		"sprite": "res://monsters/skeleton.png", "frames": 8, "scale": 1.0, "tint": Color.WHITE,
		"hp": 22, "atk": 8, "def": 4, "mag": 6, "spd": 5, "exp": 14, "gold": 22,
		"dd_job": "ninja", "dd_personality": "bluffer", "cc_actions": {"attack": 3, "spell": 1}, "cc_defense": {"block": 2, "counter": 1},
		"offense": {"attack": 5, "strike": 2, "magic": 3},
		"defense": {"guard": 4, "counter": 2, "ward": 3},
	},
	"Goblin": {
		"sprite": "res://monsters/goblin.png", "frames": 4, "scale": 1.0, "tint": Color.WHITE,
		"hp": 28, "atk": 10, "def": 5, "mag": 1, "spd": 7, "exp": 16, "gold": 30,
		"dd_job": "thief", "dd_personality": "bluffer", "cc_actions": {"attack": 1}, "cc_defense": {"block": 1, "dodge": 2},
		"offense": {"attack": 6, "strike": 4, "magic": 0},
		"defense": {"guard": 5, "counter": 3, "ward": 1},
	},
	# ผู้คุมเมือง (ใช้สไปรต์เดิม ตัวใหญ่ขึ้น + สีเปลี่ยน)
	"Goblin Chief": {
		"sprite": "res://monsters/goblin.png", "frames": 4, "scale": 1.3, "tint": Color(1.0, 0.75, 0.6),
		"hp": 60, "atk": 15, "def": 9, "mag": 2, "spd": 8, "exp": 60, "gold": 120,
		"dd_job": "warrior", "dd_personality": "aggressive", "cc_actions": {"attack": 3, "heavy_blow": 1, "guard": 1}, "cc_defense": {"block": 2, "counter": 2}, "unique_chance": 1.0, "gear_chance": 1.0,
		"offense": {"attack": 5, "strike": 4, "magic": 0},
		"defense": {"guard": 4, "counter": 4, "ward": 1},
	},
	"Bone Lord": {
		"sprite": "res://monsters/skeleton.png", "frames": 8, "scale": 1.35, "tint": Color(0.8, 0.8, 1.15),
		"hp": 55, "atk": 12, "def": 8, "mag": 14, "spd": 7, "exp": 70, "gold": 140,
		"dd_job": "magician", "dd_personality": "aggressive", "cc_actions": {"attack": 2, "spell": 2, "fireball": 1}, "cc_defense": {"block": 2, "dodge": 1}, "unique_chance": 1.0, "gear_chance": 1.0,
		"offense": {"attack": 4, "strike": 2, "magic": 5},
		"defense": {"guard": 3, "counter": 2, "ward": 5},
	},
}

const UNIQUE_DROP_CHANCE := 0.04

# มอนสเตอร์ที่สุ่มเจอในช่องต่อสู้
const WILD_MONSTERS := ["Skeleton", "Goblin"]

# ---------------------------------------------------------------- ช่องกระดาน
const TILE_TYPES := {
	"castle": {"color": Color(1.25, 1.05, 0.7), "name": "Castle"},
	"town": {"color": Color(1.2, 0.95, 1.2), "name": "Town"},
	"shop": {"color": Color(0.8, 1.2, 1.2), "name": "Shop"},
	"smithy": {"color": Color(1.35, 0.85, 0.5), "name": "Smithy"},
	"battle": {"color": Color(0.6, 0.75, 1.3), "name": "Battle"},
	"item": {"color": Color(0.75, 1.25, 0.75), "name": "Item"},
	"gold": {"color": Color(1.3, 1.2, 0.55), "name": "Gold"},
	"trap": {"color": Color(1.3, 0.6, 0.6), "name": "Trap"},
	"empty": {"color": Color(0.95, 0.95, 0.95), "name": "Empty"},
}

# เมืองที่ถูกมอนสเตอร์ยึด: ชนะผู้คุมแล้วเมืองเป็นของเรา ได้ภาษีทุกวัน
const TOWNS := {
	Vector2i(-2, 2): {"name": "Willowmere", "guard": "Goblin Chief", "tax": 20},
	Vector2i(8, 2): {"name": "Ashford", "guard": "Bone Lord", "tax": 25},
}

# ช่องพิเศษ (ช่องที่ไม่อยู่ในนี้จะสุ่มตามรูปแบบใน main.gd)
const SPECIAL_TILES := {
	Vector2i(3, -2): "castle",
	Vector2i(-2, 2): "town",
	Vector2i(8, 2): "town",
	Vector2i(3, 5): "shop",
	Vector2i(0, 0): "smithy", # หน้าบ้านร้านอาวุธ (บ้านซ้ายของปราสาท)
	Vector2i(3, -1): "empty", # หน้าปราสาท ปลอดภัย
}

# รูปแบบช่องทั่วไป วนตามลำดับ
const TILE_PATTERN := ["battle", "gold", "battle", "item", "empty", "battle", "trap", "gold", "item"]

const EXP_TO_LEVEL := 20 # exp ที่ต้องใช้ = EXP_TO_LEVEL * level
