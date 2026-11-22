# Dice Duel (prototype)

ระบบต่อสู้แบบ dice-building — ใช้แทนระบบต่อสู้เดิมของบอร์ดเกมแล้ว (ช่อง Battle และผู้คุมเมือง)

## เล่น
- **ในบอร์ดเกม**: เดินไปตกช่อง Battle หรือท้าผู้คุมเมือง (ผู้เล่น vs มอนสเตอร์ AI)
- **ฉากทดลองแยก**: เปิด `res://dice_duel/dice_duel.tscn` แล้วกด F6 — เลือกเล่นกับ AI หรือ hot-seat 2 คน และดู replay ล่าสุดได้

## รัน test / simulation (ในโฟลเดอร์โปรเจกต์)
```
Godot --headless --path . --import                                       # ครั้งแรก / หลังเพิ่ม class ใหม่
Godot --headless --path . --script res://tests/dd_tests.gd                # unit test (exit 0 = ผ่าน)
Godot --headless --path . --script res://tools/dd_simulate.gd             # AI สู้กัน 10,000 แมตช์
Godot --headless --path . --script res://tools/dd_simulate.gd -- 2000 7   # จำนวนแมตช์ / seed
```

## โครงสร้าง
| ไฟล์ | หน้าที่ |
|---|---|
| `dd_balance.gd` | ตัวเลขทั้งหมด (ไฟล์เดียว) |
| `dd_faces.gd` `dd_bodies.gd` `dd_runes.gd` | หน้าเต๋า / Body / Rune (registry + hook เพิ่มของใหม่ได้) |
| `dd_moves.gd` `dd_resolve.gd` `dd_jobs.gd` | เงื่อนไขท่า พลัง ตารางผล สกิลอาชีพ |
| `dd_battle.gd` | ตัวเดินเกมแบบ pure: `create_battle()` + `apply_action()` |
| `dd_view.gd` | `get_player_view()` ซ่อนข้อมูลลับของอีกฝ่าย |
| `dd_replay.gd` | replay จาก seed + action, บันทึกเป็น JSON |
| `dd_ai.gd` `dd_match.gd` | AI (aggressive / bluffer) และให้ AI สู้กันเอง |
| `dd_meta.gd` | ระบบนอกการต่อสู้: deface / steal rune / upgrade / Underdog Die |
| `dd_battle_ui.gd` `dd_replay_ui.gd` `dd_app.gd` | UI |
| `dd_board_bridge.gd` | แปลงผู้เล่น/มอนสเตอร์ในบอร์ดเกมเป็นตัวละคร Dice Duel |

## กติกาที่ตกลงเพิ่มจากสเปก
1. ⚔/🛡 นับคู่/คี่ตามค่าในบริบท (⚔ รุก = 6 คู่, รับ = 1 คี่)
2. 💀 ใช้กับ Slash/Guard ได้ (ค่า 0) ท่าอื่นล้ม
3. ตรวจเงื่อนไขจากค่าก่อน rune; rune มีผลแค่พลัง/การลดดาเมจ
4. ประกาศ Counter ใส่ Magic โดน ×1.5 แม้ Counter จะล้ม
5. Arcane Flow: ลูกแรก = ลูกหลัก (≥4 หรือ ✦), ลูกเพิ่มห้าม 💀, โบนัส % บวกกันก่อนคูณ
6. 1 รอบ = ปะทะ 1 ครั้ง, HP% เท่ากันหลัง 6 รอบ = เสมอ
7. Reroll ได้หลายครั้งตาม Focus; Warrior reroll ฟรีเฉพาะหน้าเลข 1
8. Heavy มีผลเฉพาะหน้าตัวเลข; Quick = d4 ได้ Focus +1 ต่อลูก
9. Swipe เลือกหลังเปิดเต๋า ค่า ✦ คงเดิม เต๋ากลับเจ้าของหลังจบรอบ Thief ฝ่ายบุกเลือกก่อน
10. ทุกอาชีพสเตตัสเท่ากัน (ปรับได้ที่ `JOB_STAT_MODS`)
11. Shadow Read สุ่มดูเต๋าที่ทอยแล้ว 1 ลูก
12. AI สุ่ม 20% เลือกท่าที่ใช้ได้แบบสุ่ม
- Sanctuary ฮีลหลังรับดาเมจ (HP ถึง 0 แล้วไม่ฟื้น)

## ปรับสมดุล (ต่างจากสเปกเดิม)
| ค่า | สเปก | ตอนนี้ | เหตุผล |
|---|---|---|---|
| `SWIPE_FOCUS_COST` | 0 | **3** | Thief ชนะ 62% — ใช้ Swipe ต้องแลกกับ Focus ทั้งหลอด |
| `COUNTER_VALUES` | [5, 6] | **[6]** | Counter สะท้อน Strike ได้ 67% จน Strike เป็นท่ากับดัก |

knob ที่มีให้ลองแต่ยังใช้ค่าตามสเปก: `SWIPE_USES_PER_BATTLE`, `SWIPE_RANDOM_TARGET`, `SLASH_VS_COUNTER_MULT`, `COUNTER_REFLECT`

ผล simulation 10,000 แมตช์ (ไม่นับ mirror):

| | Warrior | Magician | Thief | Ninja | Cleric | Strike โดนสะท้อน |
|---|---|---|---|---|---|---|
| ก่อนปรับ | 44.1% | 46.9% | 62.2% | 45.6% | 51.2% | 65% |
| หลังปรับ | 49.5% | 46.2% | 53.2% | 48.3% | 52.8% | 44% |
