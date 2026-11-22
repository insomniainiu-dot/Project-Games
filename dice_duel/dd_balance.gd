class_name DDBalance
## ตัวเลขทั้งหมดของ Dice Duel อยู่ที่ไฟล์นี้ไฟล์เดียว
## แก้ค่าแล้วรัน simulation (ดู README ใน dice_duel/) เพื่อดูผลต่อสมดุล

# ---------------------------------------------------------------- ตัวละคร
const BASE_STATS := {"hp": 100, "at": 20, "df": 15, "mg": 15, "sp": 10}
## ค่าปรับสเตตัสรายอาชีพ (บวกเพิ่มจาก BASE_STATS) — prototype ตั้งเป็น 0 ทั้งหมด
const JOB_STAT_MODS := {"warrior": {}, "magician": {}, "thief": {}, "ninja": {}, "cleric": {}}
const STARTING_DICE := 3
const MAX_ROUNDS := 6

# ---------------------------------------------------------------- Focus
const FOCUS_MAX := 3
const FOCUS_PER_ROUND := 1
const FOCUS_PER_UNPLACED_DIE := 1
const REROLL_COST := 1

# ---------------------------------------------------------------- ใครบุกก่อน: d6 + SP/5
const INITIATIVE_DIE := 6
const INITIATIVE_SP_DIVISOR := 5.0

# ---------------------------------------------------------------- ท่ารุก
const SLASH_MIN_DICE := 1
const SLASH_MAX_DICE := 2
const SLASH_PER_PIP := 0.10
const STRIKE_DICE := 2
const STRIKE_MIN_SUM := 8
const STRIKE_PER_PIP := 0.10
const STRIKE_MULT := 2.0
const MAGIC_MIN_VALUE := 4
const MAGIC_PER_PIP := 0.15

# ---------------------------------------------------------------- ท่ารับ
const GUARD_PER_PIP := 0.05
## สเปกเดิม [5, 6] — ปรับเหลือ [6] เพราะ Counter สะท้อน Strike ได้ ~67% จน Strike กลายเป็นท่ากับดัก
const COUNTER_VALUES := [6]
const WARD_PER_PIP := 0.08

# ---------------------------------------------------------------- ตารางผล
## Magic ปะทะ Counter (นับตั้งแต่ประกาศ Counter ไม่ว่าจะผ่านเงื่อนไขหรือไม่)
const MAGIC_VS_COUNTER_MULT := 1.5
## Strike ปะทะ Counter ที่ผ่านเงื่อนไข: สะท้อนกี่เท่าของพลัง
const COUNTER_REFLECT := 1.0
## Slash ปะทะ Counter (ประกาศ Counter แล้วเดาผิด) — สเปกเดิม = 1.0 (พลังเต็ม)
const SLASH_VS_COUNTER_MULT := 1.0

# ---------------------------------------------------------------- Body / Rune
const HEAVY_MIN_ROLL := 3
const QUICK_SIDES := 4
const QUICK_START_FOCUS := 1
const TWIN_MULT := 2
const SPARK_MAGIC_BONUS := 0.10

# ---------------------------------------------------------------- สกิลอาชีพ
const BERSERK_DICE := 3
const BERSERK_PER_PIP := 0.10
const BERSERK_MULT := 3.0
const ARCANE_ODD_EXTRA_BONUS := 0.15
const SANCTUARY_HEAL_PER_PIP := 2
## Swipe: ใช้ได้กี่ครั้งต่อการต่อสู้ / ต้องจ่าย Focus เท่าไร / เลือกเต๋าของอีกฝ่ายเองหรือสุ่ม
## สเปกเดิมไม่เสีย Focus — ปรับเป็น 3 (เต็มหลอด) เพราะ Thief ชนะ 62%
const SWIPE_USES_PER_BATTLE := 1
const SWIPE_FOCUS_COST := 3
const SWIPE_RANDOM_TARGET := false

# ---------------------------------------------------------------- AI
## โอกาสเลือกท่าแบบสุ่ม กันไม่ให้อ่านทางง่าย
const AI_RANDOMNESS := 0.2
## มูลค่า (เทียบเป็นดาเมจ) ของ Focus 1 แต้มจากเต๋าที่ไม่ได้วาง
const AI_FOCUS_VALUE := 2.0
## aggressive ให้น้ำหนักกับพลังดิบเพิ่ม
const AI_AGGRESSIVE_RAW_WEIGHT := 0.3
## bluffer ให้คะแนน Slash 2 ลูกเพิ่มกี่เท่า
const AI_BLUFFER_SLASH_TWO_BONUS := 1.35
## Thief ใช้ Swipe เมื่อได้เปรียบสุทธิอย่างน้อยเท่านี้ (เทียบกับพลังของตัวเอง)
const AI_SWIPE_MIN_GAIN_RATIO := 0.4
