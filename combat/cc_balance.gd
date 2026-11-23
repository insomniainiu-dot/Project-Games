class_name CCBalance
## ตัวเลขทั้งหมดของระบบต่อสู้แบบ "ช่องเช็ค" อยู่ไฟล์นี้ไฟล์เดียว
## แก้แล้วรัน simulation:  Godot --headless --path . --script res://tools/cc_simulate.gd

# ---------------------------------------------------------------- โอกาสผ่านต่อช่อง
## โอกาส = BASE + ค่าสเตตัส × PER_STAT (หน่วย %) แล้วบีบให้อยู่ใน MIN..MAX
const CHANCE_BASE := 40.0
const CHANCE_PER_STAT := 2.5
const CHANCE_MIN := 20.0
const CHANCE_MAX := 95.0

# ---------------------------------------------------------------- Focus
## Focus 1 แต้ม = เพิ่มโอกาสผ่านทุกช่องของท่านั้น +FOCUS_CHANCE_BONUS% (ใช้ได้ทั้งตอนโจมตีและตอนป้องกัน)
const FOCUS_START := 2
const FOCUS_MAX := 3
const FOCUS_ON_GUARD := 1
const FOCUS_CHANCE_BONUS := 15.0
const CHANCE_MAX_WITH_FOCUS := 100.0 ## เพดานโอกาสเมื่อใช้ Focus (ไม่ใช้ Focus เพดาน = CHANCE_MAX)

# ---------------------------------------------------------------- การป้องกันพื้นฐาน (คิดอัตโนมัติ)
const PHYS_REDUCE_PER_DEF := 0.5 ## ดาเมจกายภาพลด = DEF × ค่านี้
const MAGIC_REDUCE_PER_MAG := 1.0 / 3.0 ## ดาเมจเวทลด = MAG ฝ่ายรับ × ค่านี้
const GUARD_DAMAGE_MULT := 0.5 ## Guard รับดาเมจครึ่งเดียวจนถึงตาถัดไปของตัวเอง
const MIN_DAMAGE_ON_HIT := 1 ## ผ่านอย่างน้อย 1 ช่องแล้ว ดาเมจขั้นต่ำเท่านี้

# ---------------------------------------------------------------- เทิร์นป้องกัน
## ตอนโดนโจมตี ฝ่ายรับเลือกวิธีป้องกัน (ผู้เล่นเลือกเอง มอนสเตอร์สุ่มตาม cc_defense)
## check_magic = สเตตัสที่ใช้เช็คแทนเมื่อโดนเวท, chance_mod = ปรับ % (บวก/ลบ) เฉพาะวิธีนี้
const DEFENSES := {
	"block": {"name": "Block", "slots": 2, "check": "def", "check_magic": "mag", "chance_mod": 0.0},
	"dodge": {"name": "Dodge", "slots": 1, "check": "spd", "chance_mod": -20.0},
	"counter": {"name": "Counter", "slots": 2, "check": "atk", "chance_mod": 0.0},
}
const DEFENSE_TEXT := {
	"block": "Each pass cuts 30% damage. Perfect: +1 Focus",
	"dodge": "Pass = no damage. Fail = take x1.5",
	"counter": "Take the hit, strike back. Perfect: take half",
}
const BLOCK_CUT_PER_SUCCESS := 0.3
const DODGE_FAIL_MULT := 1.5
const COUNTER_POWER_MULT := 0.8 ## พลังตีสวน = ATK × ค่านี้ × (ช่องที่ผ่าน ÷ จำนวนช่อง)
const COUNTER_PERFECT_DAMAGE_MULT := 0.5

# ---------------------------------------------------------------- ท่า
## slots = จำนวนช่อง, check = สเตตัสที่ใช้เช็ค, power = สเตตัสที่ใช้คิดพลัง × mult
## kind = "phys" / "magic" / "flee" / "drone", perfect = โบนัสเมื่อผ่านครบทุกช่อง
##   "drone" = ไม่ตีตรง ๆ และศัตรูป้องกันไม่ได้: ผ่านอย่างน้อย 1 ช่อง = ปล่อยโดรนยิงเองทุกต้นตาของคนปล่อย
## pierce = Perfect แล้วไม่สนการลดดาเมจ (phys = ARM, magic = TEC ฝ่ายรับ)
## cost = Focus ที่ต้องจ่ายเพื่อใช้ท่า (นอกเหนือจาก Focus ที่ใช้เพิ่ม %) — มอนสเตอร์ไม่ต้องจ่าย
## คีย์ท่า (id) คงชื่อเดิมไว้ (heavy_blow / fireball / twin_stab) เปลี่ยนแค่ชื่อที่แสดง
const ACTIONS := {
	"attack": {"name": "Attack", "slots": 3, "check": "atk", "power": "atk", "mult": 1.4, "kind": "phys", "perfect": ["crit"], "cost": 0},
	"spell": {"name": "Tech Attack", "slots": 2, "check": "mag", "power": "mag", "mult": 1.4, "kind": "magic", "perfect": ["pierce"], "cost": 0},
	"heavy_blow": {"name": "Breach Strike", "slots": 4, "check": "atk", "power": "atk", "mult": 1.9, "kind": "phys", "perfect": ["stun"], "cost": 1},
	"fireball": {"name": "Mind Spike", "slots": 3, "check": "mag", "power": "mag", "mult": 1.9, "kind": "magic", "perfect": ["pierce", "burn"], "cost": 1},
	"twin_stab": {"name": "Twin Shiv", "slots": 2, "check": "spd", "power": "atk", "mult": 1.45, "kind": "phys", "perfect": ["double", "steal"], "cost": 1},
	"charged_shot": {"name": "Charged Shot", "slots": 4, "check": "atk", "power": "atk", "mult": 1.9, "kind": "phys", "perfect": ["pierce"], "cost": 1},
	"deploy_drone": {"name": "Deploy Drone", "slots": 2, "check": "mag", "power": "", "mult": 0.0, "kind": "drone", "perfect": ["long_drone"], "cost": 1},
	"flee": {"name": "Flee", "slots": 1, "check": "spd", "power": "", "mult": 0.0, "kind": "flee", "perfect": [], "cost": 0},
}
const PERFECT_TEXT := {
	"crit": "Critical x1.5",
	"pierce": "Ignores armor / resist",
	"stun": "Stuns: target skips a turn",
	"burn": "Burns for 2 turns",
	"double": "Hits again",
	"steal": "Steals credits",
	"long_drone": "Drone lasts 5 turns",
}
const CRIT_MULT := 1.5
## LCK → อัตราคริ: ท่าที่ทำดาเมจผ่าน ≥ 1 ช่อง ทอยคริ 1 ครั้ง โอกาส = LCK × CRIT_PER_LCK % (เพดาน CRIT_CHANCE_MAX)
## Perfect ของท่าที่มี "crit" (Attack) = คริแน่นอนไม่ต้องทอย · LCK 0 = ไม่ทอยเลย (ไม่กิน rng)
const CRIT_PER_LCK := 1.0
const CRIT_CHANCE_MAX := 50.0
const BURN_TURNS := 2
const BURN_DAMAGE_PER_MAG := 0.5 ## ไฟไหม้ต่อตา = MAG คนร่าย × ค่านี้
const STEAL_GOLD_RATIO := 0.25 ## ขโมยทอง = รางวัลทองของมอนสเตอร์ × ค่านี้

# ---------------------------------------------------------------- โดรน (Deploy Drone)
const DRONE_TURNS := 3 ## ผ่าน 1 ช่อง
const DRONE_TURNS_PERFECT := 5 ## ผ่านครบ
const DRONE_DAMAGE_PER_MAG := 0.6 ## ดาเมจโดรนต่อตา = TEC คนปล่อย × ค่านี้ (ไม่สนการป้องกัน) — ปล่อยซ้ำ = รีเซ็ตจำนวนตา ไม่ซ้อน

## สกิลอาชีพ (อาชีพบนบอร์ด)
const JOB_SKILL := {
	"Vanguard": "heavy_blow", "Marksman": "charged_shot", "Engineer": "deploy_drone",
	"Psion": "fireball", "Infiltrator": "twin_stab",
}

## ไอเทมในการต่อสู้: ใช้ตอนไหนและผลอะไร กำหนดที่ GameData.ITEMS (คีย์ "battle", heal/buff/damage/poison/escape)

## การต่อสู้ยาวเกินนี้ถือว่าแยกย้าย (กันวนไม่จบ)
const MAX_ROUNDS := 40

# ---------------------------------------------------------------- AI ฮีโร่ (ใช้ใน simulation)
const HERO_AI_HEAL_BELOW := 0.35 ## HP ต่ำกว่านี้ใช้ยาฮีล
