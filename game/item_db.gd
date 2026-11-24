class_name ItemDB
## อุปกรณ์ Rare / Epic = ไอเทมฐาน (GameData.ITEMS) + affix ที่สุ่มได้
## เก็บเป็น instance id แบบ "ชื่อฐาน#เลข" (string เหมือนไอเทมทั่วไป ใส่ gear / ช่องสวมใส่ได้เลย)
## ข้อมูลรวมของไอเทม (ฐาน + affix) ดึงด้วย ItemDB.data(id) หรือ GameData.item(id)
## affix เป็นสเตตัสตรง ๆ หรือ mods (คีย์เดียวกับ PassiveTree) → ระบบต่อสู้ใช้ได้เลยผ่าน PlayerStats.battle_mods()

# ---------------------------------------------------------------- Tier
## affixes = [ต่ำสุด, สูงสุด] จำนวน affix, price_mult = ตัวคูณราคา (ขายคืน)
const TIERS := {
	"common": {"name": "Common", "affixes": [0, 0], "price_mult": 1.0, "color": Color(1, 1, 1)},
	"rare": {"name": "Rare", "affixes": [1, 2], "price_mult": 1.6, "color": Color(0.95, 0.85, 0.35)},
	"epic": {"name": "Epic", "affixes": [3, 4], "price_mult": 2.5, "color": Color(0.75, 0.5, 1.0)},
	"unique": {"name": "Unique", "affixes": [0, 0], "price_mult": 1.0, "color": Color(1.0, 0.6, 0.25)},
}

# ---------------------------------------------------------------- ดรอป
## ชนะแล้วมีโอกาสได้อุปกรณ์ GEAR_DROP_CHANCE (MONSTERS "gear_chance" ทับได้) — ฐานสุ่มจาก SMITHY_STOCK ทุกหมวด
const GEAR_DROP_CHANCE := 0.25
const DROP_TIER_WEIGHTS := {"rare": 75, "epic": 25}

# ---------------------------------------------------------------- Affix
## stat = บวกสเตตัสตรง ๆ, mod = คีย์ mods · ค่าสุ่ม min..max
## pct_mult = ค่าเป็น % แล้วเก็บใน mods เป็นตัวคูณ (1 + v/100) · slots = ช่องอุปกรณ์ที่ออกได้ · weight = น้ำหนักสุ่ม
## affix เดียวกันออกได้ครั้งเดียวต่อชิ้น
const AFFIXES := {
	"atk": {"stat": "atk", "min": 1, "max": 4, "slots": ["weapon", "accessory"], "weight": 10},
	"mag": {"stat": "mag", "min": 1, "max": 4, "slots": ["weapon", "accessory"], "weight": 10},
	"def": {"stat": "def", "min": 1, "max": 4, "slots": ["armor", "accessory"], "weight": 10},
	"hp": {"stat": "hp", "min": 4, "max": 12, "slots": ["armor", "accessory"], "weight": 10},
	"spd": {"stat": "spd", "min": 1, "max": 2, "slots": ["weapon", "armor", "accessory"], "weight": 6},
	"lck": {"stat": "lck", "min": 2, "max": 5, "slots": ["weapon", "accessory"], "weight": 6},
	"attack_dmg": {"mod": "attack_mult", "pct_mult": true, "min": 5, "max": 15, "slots": ["weapon"], "weight": 8, "text": "Attack damage +%d%%"},
	"perfect_dmg": {"mod": "perfect_mult", "pct_mult": true, "min": 5, "max": 12, "slots": ["weapon", "accessory"], "weight": 6, "text": "Perfect hits deal +%d%% damage"},
	"first_slot": {"mod": "first_slot_bonus.attack", "min": 5, "max": 10, "slots": ["weapon"], "weight": 6, "text": "Attack: first slot +%d%% chance"},
	"block": {"mod": "check_bonus.block", "min": 4, "max": 8, "slots": ["armor"], "weight": 8, "text": "Block +%d%% chance"},
	"guard_heal": {"mod": "guard_heal_pct", "min": 3, "max": 5, "slots": ["armor"], "weight": 6, "text": "Guard heals %d%% max HP"},
	"barrier": {"mod": "start_barrier", "min": 3, "max": 8, "slots": ["armor", "accessory"], "weight": 6, "text": "Start battles with %d Barrier"},
	"regen": {"mod": "regen", "min": 1, "max": 2, "slots": ["armor", "accessory"], "weight": 4, "text": "Regenerate %d HP per turn"},
	"burn": {"mod": "poison_bonus", "min": 1, "max": 2, "slots": ["weapon", "accessory"], "weight": 4, "text": "Burn / poison +%d damage"},
}

## instance id -> {"base", "tier", "affixes": [{"id", "value"}]}
static var _instances := {}
static var _next := 1


# ================================================================ สร้าง
## สร้างอุปกรณ์ tier นี้จากฐาน base (สุ่ม affix ด้วย rng) คืน instance id — common คืนชื่อฐานเลย
static func create(base: String, tier: String, rng: RandomNumberGenerator) -> String:
	if tier == "common" or tier == "unique" or not TIERS.has(tier):
		return base
	var slot: String = GameData.ITEMS[base].type
	var r: Array = TIERS[tier].affixes
	var count := rng.randi_range(r[0], r[1])
	var pool := {}
	for a in AFFIXES:
		if AFFIXES[a].slots.has(slot):
			pool[a] = AFFIXES[a].weight
	var affixes := []
	for i in count:
		if pool.is_empty():
			break
		var a := CCBattle._pick(pool, rng)
		pool.erase(a)
		affixes.append({"id": a, "value": rng.randi_range(AFFIXES[a].min, AFFIXES[a].max)})
	return register({"base": base, "tier": tier, "affixes": affixes})


## ลงทะเบียน record ที่มีอยู่แล้ว (ใช้ตอนโหลดเซฟ / test) คืน instance id ใหม่
static func register(record: Dictionary) -> String:
	var id := "%s#%d" % [record.base, _next]
	_next += 1
	_instances[id] = record.duplicate(true)
	return id


## ลงทะเบียนด้วย id เดิม (โหลดเซฟ) — ตัวนับ id ขยับให้เกินเลขที่โหลดมา กัน id ชนกับของใหม่
static func restore(id: String, rec: Dictionary) -> void:
	var r := rec.duplicate(true)
	for a in r.get("affixes", []):
		a.value = int(a.value) # JSON เก็บตัวเลขเป็น float
	if r.has("plus"):
		r.plus = int(r.plus)
	_instances[id] = r
	var n := int(id.get_slice("#", 1))
	_next = maxi(_next, n + 1)


## ทำให้ไอเทมเป็น instance (Common / Unique ที่เป็นแค่ชื่อ) เพื่อเก็บค่าเฉพาะชิ้น เช่น ระดับ Overclock
## ของที่เป็น instance อยู่แล้วคืน id เดิม · ไอเทมที่ไม่ใช่อุปกรณ์คืน id เดิม
static func promote(id: String) -> String:
	if _instances.has(id) or not GameData.ITEMS.has(id) or GameData.ITEMS[id].get("type", "") == "use":
		return id
	return register({"base": id, "tier": GameData.ITEMS[id].get("rarity", "common"), "affixes": []})


## ราคาตาม tier ไม่รวม Overclock (ใช้คิดค่า Overclock)
static func base_price(id: String) -> int:
	var b := base_of(id)
	var tier: String = record(id).get("tier", GameData.ITEMS.get(b, {}).get("rarity", "common"))
	return roundi(int(GameData.ITEMS.get(b, {}).get("price", 0)) * float(TIERS.get(tier, TIERS.common).price_mult))


static func plus_of(id: String) -> int:
	return int(record(id).get("plus", 0))


static func set_plus(id: String, n: int) -> void:
	if _instances.has(id):
		_instances[id].plus = n


## สุ่ม tier ตาม DROP_TIER_WEIGHTS แล้วสุ่มฐานจากของในร้าน Smithy
static func random_drop(rng: RandomNumberGenerator) -> String:
	var bases := []
	for cat in GameData.SMITHY_STOCK:
		bases.append_array(GameData.SMITHY_STOCK[cat])
	var base: String = bases[rng.randi_range(0, bases.size() - 1)]
	return create(base, CCBattle._pick(DROP_TIER_WEIGHTS, rng), rng)


# ================================================================ อ่านข้อมูล
static func is_instance(id: String) -> bool:
	return _instances.has(id)


static func base_of(id: String) -> String:
	return _instances[id].base if _instances.has(id) else id


static func record(id: String) -> Dictionary:
	return _instances.get(id, {})


## ข้อมูลรวมของไอเทม: ฐาน + สเตตัส/mods จาก affix + "rarity" + "price" ตาม tier
static func data(id: String) -> Dictionary:
	if not _instances.has(id):
		return GameData.ITEMS.get(id, {})
	var rec: Dictionary = _instances[id]
	var out: Dictionary = GameData.ITEMS[rec.base].duplicate(true)
	out.rarity = rec.tier
	out.price = roundi(out.get("price", 0) * float(TIERS[rec.tier].price_mult))
	var mods: Dictionary = out.get("mods", {})
	for a in rec.affixes:
		var def: Dictionary = AFFIXES[a.id]
		if def.has("stat"):
			out[def.stat] = int(out.get(def.stat, 0)) + int(a.value)
		else:
			var v = (1.0 + a.value / 100.0) if def.get("pct_mult", false) else a.value
			mods = CCBalance.merge_mods(mods, {def.mod: v})
	var plus := int(rec.get("plus", 0))
	if plus > 0: # Overclock: ค่าพลังบวกทุกตัว +STAT_PCT% ต่อระดับ (ปัดขึ้น อย่างน้อย +1 ต่อระดับ)
		for k in GameData.STAT_KEYS:
			var v := int(out.get(k, 0))
			if v > 0:
				out[k] = v + maxi(plus, ceili(v * Overclock.STAT_PCT * plus / 100.0))
		out.plus = plus
		out.price = roundi(out.price * (1.0 + Overclock.PRICE_PCT_PER_PLUS * plus / 100.0)) # ขายได้แพงขึ้น
	var mark: String = rec.get("mark", "")
	if mark != "": # ตราข้ามฝ่าย (ซื้อจากร้านฝ่ายตรงข้าม) — ดู FactionShop
		mods = CCBalance.merge_mods(mods, {"attack_mult": FactionShop.MARK_ATTACK_MULT})
		if mark == "concord":
			out.spd = int(out.get("spd", 0)) + FactionShop.CONCORD_MARK_SPD
		out.mark = mark
		out.karma_per_battle = FactionShop.MARK_KARMA if mark == "concord" else -FactionShop.MARK_KARMA
	if not mods.is_empty():
		out.mods = mods
	return out


## ติดตราข้ามฝ่ายให้ instance ("concord" / "syndicate")
static func set_mark(id: String, mark: String) -> void:
	if _instances.has(id):
		_instances[id].mark = mark


## ข้อความ affix ทีละบรรทัด เช่น "+3 ATK", "Attack damage +10%" (+ ตราถ้ามี)
static func affix_lines(id: String) -> PackedStringArray:
	var lines := PackedStringArray()
	for a in record(id).get("affixes", []):
		var def: Dictionary = AFFIXES[a.id]
		if def.has("stat"):
			lines.append("+%d %s" % [a.value, GameData.stat_label(def.stat)])
		else:
			lines.append(def.text % a.value)
	var mark: String = record(id).get("mark", "")
	if mark != "":
		lines.append(FactionShop.mark_text(mark))
	return lines


static func color(id: String) -> Color:
	return TIERS.get(GameData.rarity(id), TIERS.common).color
