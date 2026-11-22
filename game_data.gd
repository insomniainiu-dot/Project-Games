class_name GameData
## ข้อมูลเกมทั้งหมด (อาชีพ / ไอเทม / มอนสเตอร์ / ช่องกระดาน / เมือง)
## เพิ่ม-แก้ของในเกมได้ที่ไฟล์นี้ไฟล์เดียว ไม่ต้องแตะโค้ดส่วนอื่น

# ---------------------------------------------------------------- อาชีพ
# base = ค่าเริ่มต้นที่ Lv1, grow = ค่าที่เพิ่มต่อเลเวล
const JOBS := {
	"Mage": {
		"desc": "Strong magic, weak body.",
		"base": {"hp": 26, "atk": 5, "def": 4, "mag": 10, "spd": 6},
		"grow": {"hp": 5, "atk": 1, "def": 1, "mag": 3, "spd": 1},
	},
	"Fighter": {
		"desc": "Hits hard, takes hits.",
		"base": {"hp": 34, "atk": 9, "def": 7, "mag": 2, "spd": 5},
		"grow": {"hp": 7, "atk": 3, "def": 2, "mag": 0, "spd": 1},
	},
	"Rogue": {
		"desc": "Fast, lucky with gold.",
		"base": {"hp": 28, "atk": 7, "def": 5, "mag": 4, "spd": 10},
		"grow": {"hp": 5, "atk": 2, "def": 1, "mag": 1, "spd": 3},
	},
}

# ---------------------------------------------------------------- ไอเทม
# type: "use" = ใช้แล้วหมดไป, "weapon"/"armor"/"accessory" = อุปกรณ์สวมใส่
# battle (ไอเทมใช้แล้วหมด): ใช้ในการต่อสู้ได้ตอนไหน "attack" = เทิร์นบุก, "defense" = เทิร์นป้องกัน, "any" = ทั้งสอง
#   ผลในการต่อสู้: heal / buff {สเตตัส: +ค่า} (ตลอดการต่อสู้นั้น) / damage (โดนแน่นอน) / poison {turns, damage} / escape
# die_body / die_rune (ไม่ใส่ก็ได้): ใน Dice Duel เต๋าลูกของช่องนั้น (อาวุธ=ลูก 1, เกราะ=ลูก 2, เครื่องประดับ=ลูก 3) ได้ Body/Rune นี้
const ITEMS := {
	"Herb": {"type": "use", "battle": "defense", "price": 15, "heal": 20, "desc": "Heal 20 HP. (Battle: defense turn)"},
	"Big Herb": {"type": "use", "battle": "defense", "price": 40, "heal": 60, "desc": "Heal 60 HP. (Battle: defense turn)"},
	"Power Tonic": {"type": "use", "battle": "defense", "price": 45, "buff": {"atk": 4, "mag": 4}, "desc": "ATK and MAG +4 for this battle. (Battle: defense turn)"},
	"Iron Tonic": {"type": "use", "battle": "defense", "price": 40, "buff": {"def": 5}, "desc": "DEF +5 for this battle. (Battle: defense turn)"},
	"Fire Bomb": {"type": "use", "battle": "attack", "price": 35, "damage": 12, "desc": "Deal 12 damage, never misses. (Battle: attack turn)"},
	"Poison Dart": {"type": "use", "battle": "attack", "price": 30, "poison": {"turns": 3, "damage": 4}, "desc": "Poison: 4 damage for 3 turns. (Battle: attack turn)"},
	"Smoke Ball": {"type": "use", "battle": "any", "price": 25, "escape": true, "desc": "Escape a battle for sure. (Battle: any turn)"},
	# อาวุธ
	"Oak Staff": {"type": "weapon", "price": 0, "atk": 1, "mag": 2, "desc": "A plain staff."},
	"Moon Rod": {"type": "weapon", "price": 90, "atk": 2, "mag": 6, "desc": "A rod that glows under the moon."},
	"Iron Blade": {"type": "weapon", "price": 110, "atk": 6, "desc": "A sturdy iron sword."},
	"Hunter Bow": {"type": "weapon", "price": 150, "atk": 5, "spd": 3, "die_body": "quick", "desc": "Light and quick. (Quick die)"},
	"Sun Staff": {"type": "weapon", "price": 220, "atk": 3, "mag": 10, "die_rune": "spark", "desc": "Burns with solar magic. (Spark rune)"},
	"War Axe": {"type": "weapon", "price": 260, "atk": 11, "spd": -1, "die_body": "heavy", "desc": "Heavy, but hits like a cart. (Heavy die)"},
	# ชุดเกราะ
	"Travel Cloak": {"type": "armor", "price": 0, "def": 1, "desc": "A worn cloak."},
	"Leather Vest": {"type": "armor", "price": 70, "def": 4, "desc": "Simple leather protection."},
	"Rune Robe": {"type": "armor", "price": 120, "def": 3, "mag": 3, "spd": 1, "desc": "Stitched with runes."},
	"Chain Mail": {"type": "armor", "price": 180, "def": 8, "spd": -1, "desc": "Linked steel rings."},
	"Knight Plate": {"type": "armor", "price": 300, "hp": 10, "def": 13, "spd": -2, "die_body": "heavy", "desc": "Full plate of a royal knight. (Heavy die)"},
	# เครื่องประดับ
	"Lucky Charm": {"type": "accessory", "price": 60, "spd": 3, "desc": "A four-leaf clover in glass."},
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
const STAT_KEYS := ["hp", "atk", "def", "mag", "spd"]
const MAX_ITEMS := 6
const MAX_GEAR := 8 # อุปกรณ์สำรอง (ที่ยังไม่ได้สวม) เก็บได้กี่ชิ้น
const SELL_RATE := 0.5 # ขายคืนได้ครึ่งราคา


## ข้อความค่าพลังของอุปกรณ์ เช่น "ATK+6 SPD-1"
static func stat_text(item: String) -> String:
	var d: Dictionary = ITEMS[item]
	var parts := PackedStringArray()
	for k in STAT_KEYS:
		var v: int = d.get(k, 0)
		if v != 0:
			parts.append("%s%+d" % [str(k).to_upper(), v])
	return " ".join(parts)


static func sell_price(item: String) -> int:
	return int(ITEMS[item].price * SELL_RATE)

# ---------------------------------------------------------------- มอนสเตอร์
# sprite: ไฟล์สไปรต์ชีต (แถว 0 = หันหน้า, แถว 1 = หันซ้าย), frames = จำนวนเฟรมต่อแถว
# cc_actions: ท่าของมอนสเตอร์ในระบบต่อสู้ช่องเช็ค {ท่า: น้ำหนักการสุ่ม} (ท่าดูใน CCBalance.ACTIONS, "guard" = ตั้งการ์ด)
# cc_defense: วิธีป้องกันของมอนสเตอร์ตอนโดนโจมตี {block/dodge/counter: น้ำหนักการสุ่ม}
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
		"dd_job": "warrior", "dd_personality": "aggressive", "cc_actions": {"attack": 3, "heavy_blow": 1, "guard": 1}, "cc_defense": {"block": 2, "counter": 2},
		"offense": {"attack": 5, "strike": 4, "magic": 0},
		"defense": {"guard": 4, "counter": 4, "ward": 1},
	},
	"Bone Lord": {
		"sprite": "res://monsters/skeleton.png", "frames": 8, "scale": 1.35, "tint": Color(0.8, 0.8, 1.15),
		"hp": 55, "atk": 12, "def": 8, "mag": 14, "spd": 7, "exp": 70, "gold": 140,
		"dd_job": "magician", "dd_personality": "aggressive", "cc_actions": {"attack": 2, "spell": 2, "fireball": 1}, "cc_defense": {"block": 2, "dodge": 1},
		"offense": {"attack": 4, "strike": 2, "magic": 5},
		"defense": {"guard": 3, "counter": 2, "ward": 5},
	},
}

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
