# ระบบอาชีพ + Passive Tree — ธีม Sci-Fi อวกาศ (Design v2)

แนวคิด: ได้ความรู้สึก "สร้างบิลด์" แบบ ARPG ยุคใหม่ (อาชีพหลัก → อาชีพขั้นสูง → passive tree ร่วม)
แต่ย่อให้เล็ก **เห็นทั้งต้นในหน้าจอเดียว ไม่ต้องซูม ไม่ต้องอ่านคู่มือ** และเข้ากับเกมกระดาน + ระบบต่อสู้ช่องเช็คที่มีอยู่

- **5 อาชีพหลัก** · **10 อาชีพขั้นสูง** (อาชีพละ 2 ทาง)
- ทุกอย่างเป็นของเราเอง (ชื่ออาชีพ / ชื่อโหนด / layout) เอาแค่โครงสร้างแนวเกมมาใช้

v1 (ธีมแฟนตาซี 3 อาชีพ) ถูกแทนที่ด้วยเอกสารนี้

---

## 0. ธีม: เปลี่ยนชื่อที่ผู้เล่นเห็น ไม่เปลี่ยนคีย์ในโค้ด

ค่าพลังในโค้ดยังใช้คีย์เดิม (`hp / atk / def / mag / spd`) เพื่อไม่ต้องแก้ระบบต่อสู้และ test ที่มีอยู่ เปลี่ยนแค่ชื่อที่แสดง

| คีย์ในโค้ด | ชื่อที่แสดง | ความหมาย |
|---|---|---|
| `hp` | **HP** | พลังชีวิต |
| `atk` | **ATK** (Firepower) | อาวุธปืน/ระยะประชิด |
| `def` | **ARM** (Armor) | เกราะ |
| `mag` | **TEC** (Tech/Psi) | เทคโนโลยี + พลังจิต (แทนเวท) |
| `spd` | **SPD** | ความเร็ว |
| `lck` *(ใหม่)* | **LCK** (Luck) | อัตราคริติคอล — ดูข้อ 2.1 |
| Focus | **Charge** | แต้มเพิ่ม % ช่องเช็ค (กติกาเดิม) |

ของในเกมที่ต้องเปลี่ยนธีมตาม (ทำใน T-068 แยกต่างหาก ไม่ใช่ส่วนของระบบอาชีพ):

| เดิม | Sci-Fi |
|---|---|
| Castle (ปราสาท) | **Mothership** ยานแม่ (จุดเปลี่ยนอาชีพ / รีเซ็ตต้น) |
| เมือง | **Colony** อาณานิคม |
| Shop / Smithy | **Supply Depot** / **Fabricator** |
| โบสถ์ / พักฟื้น | **Med Bay** |
| Gold | **Credits** |
| Spell / Fireball / ติดไฟ / พิษ / มึน | Tech Attack / ท่าอาชีพ / **Plasma Burn** / **Corrosion** / **EMP Stun** |

---

## 1. ภาพรวม 3 ชั้น

| ชั้น | ได้มาจาก | ทำอะไร | เปลี่ยนได้ไหม |
|---|---|---|---|
| **อาชีพหลัก** (5 อาชีพ) | เลือกตอนเริ่มเกม | ค่าพลังเริ่มต้น + การเติบโต, ท่าประจำอาชีพ 1 ท่า, ความสามารถบนกระดาน 1 อย่าง, **จุดเริ่มบน Passive Tree** | เปลี่ยนที่ Mothership (เลเวลตัวละครคงเดิม) |
| **Passive Tree** (ต้นเดียวใช้ร่วมทุกอาชีพ) | 1 แต้มต่อเลเวลตัวละคร | เพิ่มค่าพลัง / ปรับกติกาการต่อสู้ช่องเช็ค / โบนัสบนกระดาน | รีเซ็ตที่ Mothership |
| **อาชีพขั้นสูง** (2 ทางต่ออาชีพ = 10) | Job Level ของอาชีพนั้น | ต้นเล็ก 3 ชั้น เลือก 1 ใน 2 ต่อชั้น, อัปเกรดท่าประจำอาชีพ | สลับทางได้ที่ Mothership (เสีย Credits) |

หลักความง่าย:
- ทุกโหนดเขียนเป็นตัวเลขตรง ๆ เช่น "Block ผ่านง่ายขึ้น +10% ทุกช่อง" ไม่มีศัพท์ลอย ๆ
- ใช้ค่าพลัง 6 ตัว (HP / ATK / ARM / TEC / SPD / LCK) + Charge ไม่เพิ่มสเตตัสอื่นอีก
- ต้น ~46 โหนด ได้ ~19 แต้มที่เลเวล 20 → ลงได้ราว 40% ต้องเลือกจริงแต่ไม่หลง

---

## 2. อาชีพหลัก 5 อาชีพ

| อาชีพ | บทบาท | ค่าพลังเด่น | ท่าประจำอาชีพ | ความสามารถบนกระดาน | แขนบนต้น |
|---|---|---|---|---|---|
| **Vanguard** | แทงก์ประชิด | HP / ATK / ARM | **Breach Strike** — 4 ช่อง ATK, Perfect: EMP Stun ข้ามตา | ความเสียหายจากกับดัก/อุกกาบาต −50% | **Assault** (แดง) |
| **Marksman** | ยิงแม่น | ATK / SPD | **Charged Shot** — 4 ช่อง ATK, Perfect: ไม่สน ARM | exp จากการต่อสู้ +15% | **Precision** (ส้ม) |
| **Engineer** | สายเครื่องจักร | TEC / ARM | **Deploy Drone** — 2 ช่อง TEC, โดรนยิงเพิ่มตาละ TEC×0.6 นาน 3 ตา (Perfect 5 ตา) | ราคา Fabricator / Supply Depot −15% | **Machine** (เหลือง) |
| **Psion** | พลังจิต ตัวบาง | TEC สูงมาก | **Mind Spike** — 3 ช่อง TEC, Perfect: ไม่สนการลด TEC + Plasma Burn 2 ตา | ฟื้นฟูที่ Med Bay +50% | **Psi** (ม่วง) |
| **Infiltrator** | เร็ว แอบขโมย | SPD | **Twin Shiv** — 2 ช่อง SPD, Perfect: ตี 2 ครั้ง + ขโมย Credits | Credits จากช่องกระดาน/มอนสเตอร์เพิ่ม (ระบบ Rogue เดิม) | **Shadow** (เขียว) |

ค่าพลังเริ่มต้น (ร่าง v2 มี LCK, ปรับใน T-065):

หลักการ: ATK+ARM+TEC+SPD+LCK เริ่มต้นรวม **28** เท่ากันทุกอาชีพ, โตรวม **6 ต่อเลเวล** เท่ากัน · HP ใช้ชดเชยอาชีพตัวบาง

| อาชีพ | HP | ATK | ARM | TEC | SPD | LCK | grow hp / atk / def / mag / spd / lck |
|---|---|---|---|---|---|---|---|
| Vanguard | 34 | **9** | **8** | 2 | 5 | 4 | 7 / 3 / 2 / 0 / 1 / 0 |
| Marksman | 28 | **8** | 4 | 3 | 5 | **8** | 5 / 2 / 1 / 0 / 1 / 2 |
| Engineer | 30 | 5 | **7** | **9** | 4 | 3 | 6 / 1 / 2 / 2 / 1 / 0 |
| Psion | 26 | 4 | 4 | **11** | 5 | 4 | 5 / 0 / 1 / 3 / 1 / 1 |
| Infiltrator | 28 | 6 | 4 | 3 | **9** | **6** | 5 / 1 / 1 / 0 / 3 / 1 |

Marksman = คริสูงสุด (สายสไนเปอร์ ต่อยอดไป Deadeye) · Infiltrator = SPD สูงสุด คริรอง

### 2.1 LCK และคริติคอล

| | กติกา |
|---|---|
| อัตราคริ | **LCK × 1%** (เพดาน 50%) |
| ทอยเมื่อไหร่ | ท่าที่ทำดาเมจ (phys / magic) ผ่าน **≥ 1 ช่อง** → ทอยคริ 1 ครั้งต่อการใช้ท่า (Twin Shiv ตี 2 ครั้ง = ทอยครั้งเดียวใช้ทั้งคู่) |
| คริแล้ว | ดาเมจ ×1.5 (คิดก่อนลบ ARM เหมือน crit เดิม) — Breacher / Deadeye ปรับตัวคูณนี้ |
| Perfect ของ Attack | **คริแน่นอน** เหมือนเดิม (ไม่ทอย และไม่ซ้อน ×1.5 สองรอบ) |
| ไม่คริ | โดรน, Plasma Burn / Corrosion, Counter, ไอเทม |
| มอนสเตอร์ | มี `lck` ด้วย ค่าเริ่มต้น 0 ใส่ให้เฉพาะตัวที่อยากให้ดุ (บอส / มอนสเตอร์สายนักฆ่า) |
| UI | บรรทัดค่าพลังในการต่อสู้เพิ่ม `LCK x (CRIT x%)` · log ขึ้น "CRITICAL!" |

LCK **ไม่**ใช้เป็นค่าเช็คช่อง (ไม่มีท่าไหน `check: "lck"`) เพื่อให้ความหมายเดียว: LCK = คริ

> **ทำแล้ว (T-070):** `CCBattle.crit_chance` / `auto_crit`, ทอยใน `_exchange` หลังเช็คหลบ (LCK 0 ไม่ทอย = seed เดิมของมอนสเตอร์ไม่เปลี่ยน), log `{"t": "effect", "effect": "crit"}` ·
> ค่าคงที่ `CRIT_PER_LCK` / `CRIT_CHANCE_MAX` ใน `cc_balance.gd` · บนต้น: `precision_out` และ `shadow_r` เปลี่ยนเป็น +3 LCK, HUB +1 LCK ·
> Lucky Charm เปลี่ยนเป็น SPD+1 LCK+5 · Breacher ใช้กับคริทุกแบบของ Attack

ย้ายจากของเดิม: Fighter → Vanguard, Mage → Psion, Rogue → Infiltrator (ใช้ตัวเลขเดิม) · ใหม่: Marksman, Engineer

ท่าใหม่ที่ต้องเพิ่มใน engine: Charged Shot (Perfect ไม่สน ARM) และ Deploy Drone (สถานะ "drone" บนตัวผู้เล่น ยิงทุกตา — กลไกคล้ายพิษ แต่ทำดาเมจใส่ศัตรู)

---

## 3. Passive Tree

### 3.1 รูปร่าง: ดาว 5 แฉก

```
                         [K] Assault
                             |
                        (N)-(n)-(N)
                         \   |   /
               (b)------- (S) Vanguard -------(b)
              /                                  \
   [K]-(N)-(S) Infiltrator                Marksman (S)-(N)-[K]
       Shadow   \                          /   Precision
                 (n)       ( HUB )       (n)
                   \      /       \      /
                    (b)--/         \--(b)
                   /                     \
          Psion (S)-(N)-[K]       [K]-(N)-(S) Engineer
            Psi    \                   /    Machine
                    `-------(b)-------'
```

`(S)` จุดเริ่มอาชีพ (ฟรี) · `(n)` โหนดเล็ก · `(N)` Notable · `[K]` Keystone · `(b)` สะพานระหว่างแขนติดกัน · `HUB` ศูนย์กลาง (ภาพนี้ย่อ จำนวนจริงดูตาราง 3.2)

กติกา: ลงแต้มได้เฉพาะโหนดที่ **ติดกับโหนดที่ลงไว้แล้ว** — UI เรืองแสงโหนดที่ลงได้ให้เห็นทันที
แขนที่อยู่ติดกันเชื่อมกันด้วยสะพาน → บิลด์ลูกผสมทำได้กับอาชีพข้าง ๆ แต่แขนฝั่งตรงข้ามต้องเดินผ่าน HUB (ไกลกว่า)

ลำดับแขนรอบวง (กำหนดว่าใครติดกับใคร): Vanguard – Marksman – Engineer – Psion – Infiltrator – (กลับมา Vanguard)

### 3.2 ชนิดโหนด

| ชนิด | ต่อแขน | รวม | ตัวอย่างผล | ราคา |
|---|---|---|---|---|
| จุดเริ่ม | 1 | 5 | – | ฟรี (ของอาชีพตัวเอง) |
| โหนดเล็ก | 4 | 20 | +5 HP / +2 ATK / +2 ARM / +2 TEC / +2 SPD / +3 LCK (+3% คริ) | 1 แต้ม |
| Notable | 3 | 15 | ปรับกติกาการต่อสู้ 1 อย่าง | 1 แต้ม |
| Keystone | 1 | 5 | แรงมาก + ข้อเสียชัดเจน (ปลายแขน) | 1 แต้ม |
| สะพาน | – | 5 | Notable ข้ามสาย ระหว่างแขนที่ติดกัน | 1 แต้ม |
| HUB | – | 1 | +3 HP และ +1 ค่าพลังอื่นทุกตัว (ทางผ่าน) | 1 แต้ม |
| | | **51** | | |

### 3.3 Notable / Keystone (ร่างแรก)

**Assault (Vanguard)**
- *Reinforced Plating* — Block ผ่านง่ายขึ้น +10% ทุกช่อง
- *Adrenal Surge* — ใช้ Guard แล้วฮีล 10% HP สูงสุด
- *Breacher* — Attack Perfect: Critical ×1.5 → ×1.8
- **[K] Juggernaut** — Block ลดช่องละ −40% (เดิม −30%) แต่ **Dodge ไม่ได้**

**Precision (Marksman)**
- *Steady Aim* — Attack ช่องแรกผ่านง่ายขึ้น +20%
- *Weak Point* — Perfect ทุกท่าไม่สน ARM 25%
- *Quick Draw* — รอบแรกของทุกการต่อสู้ ได้เล่นก่อนเสมอ (ไม่สน SPD)
- **[K] One Shot** — ท่าที่มี 4 ช่องขึ้นไป ดาเมจ ×1.4 แต่ท่า 1–2 ช่อง ดาเมจ ×0.6

**Machine (Engineer)**
- *Overclocked Drones* — โดรนอยู่นานขึ้น +1 ตา
- *Auto-Repair* — จบแต่ละตาฮีล 2 HP
- *Kinetic Barrier* — เริ่มการต่อสู้มีเกราะพลังงาน ดูดดาเมจ 10 แรก
- **[K] Full Automation** — โดรนดาเมจ ×2 แต่ Attack ธรรมดาดาเมจ ×0.6

**Psi (Psion)**
- *Deep Focus* — เริ่มการต่อสู้ด้วย Charge +1
- *Plasma Feed* — Plasma Burn อยู่นานขึ้น +1 ตา
- *Psi Shield* — Block ด้วย TEC (กันโจมตีเทค) ผ่านง่ายขึ้น +15%
- **[K] Glass Mind** — TEC +30% แต่ HP สูงสุด −25%

**Shadow (Infiltrator)**
- *Light Step* — Dodge ไม่มีโทษ −20% อีกต่อไป
- *Pickpocket* — Credits จากช่องกระดานและมอนสเตอร์ +20%
- *Second Chance* — ช่องเช็คแรกที่พลาดในแต่ละการต่อสู้ ทอยใหม่ฟรี 1 ครั้ง
- **[K] All or Nothing** — Perfect ดาเมจ ×2 แต่ไม่ Perfect ดาเมจ ×0.7

**สะพาน (ระหว่างแขนที่ติดกัน)**
- *Point Blank* (Vanguard–Marksman) — Counter ตีสวน ATK×0.8 → ×1.0
- *Smart Rounds* (Marksman–Engineer) — Attack ใช้ (ATK + TEC) ÷ 2 ถ้าสูงกว่า ATK
- *Neural Link* (Engineer–Psion) — มีโดรนอยู่ → ทุกช่องเช็ค TEC +5%
- *Toxic Mind* (Psion–Infiltrator) — Corrosion ทุกแบบ +1 ดาเมจต่อตา
- *Ambush* (Infiltrator–Vanguard) — ตาแรกของการต่อสู้ Attack +1 ช่อง

### 3.4 แต้มและการรีเซ็ต
- ได้ **1 แต้มต่อเลเวลตัวละคร** (Lv2 ขึ้นไป) — แต้มเป็นของตัวละคร ไม่ใช่ของอาชีพ
- ลงแต้มได้ทุกที่ทุกเวลา (เปิดจากเมนูสถานะ) มีปุ่ม **Confirm / Cancel** ก่อนยืนยัน
- **รีเซ็ตทั้งต้น** ที่ Mothership: ฟรีจนถึง Lv5, หลังจากนั้น 10 × เลเวล Credits
- ปุ่ม **"ลงตามแนะนำ"**: แต่ละอาชีพมีเส้นทางแนะนำ (`suggested`) กดทีเดียวลงแต้มที่เหลือให้

> Passive Tree **แทนที่** T-022 (อัปค่าพลังเองตอนเลเวลอัป) — โหนดเล็กทำหน้าที่เดียวกัน จะได้ไม่มี 2 ระบบซ้อนกัน

---

## 4. เปลี่ยนอาชีพ (Mothership)

กติกาเดียว จำง่าย: **"แต่ละอาชีพจำต้นของตัวเองไว้"**

1. เลเวลตัวละครและจำนวนแต้มคงเดิม
2. ตอนเปลี่ยน ต้นปัจจุบันถูก **เก็บไว้กับอาชีพเดิม** แล้วโหลดต้นของอาชีพใหม่ (ครั้งแรก = ว่าง ได้แต้มคืนทั้งหมดไปลงใหม่)
3. เปลี่ยนกลับมาอาชีพเดิม = ได้ต้นเดิมคืนทันที ไม่ต้องลงใหม่
4. Job Level และอาชีพขั้นสูงก็เก็บแยกต่ออาชีพเช่นกัน
5. ค่าเปลี่ยนอาชีพ: ฟรี (เหมือนตอนนี้) — ถ้าเจอว่าเปลี่ยนบ่อยเกิน ค่อยเพิ่มค่า Credits หรือให้เสีย 1 วัน

ผู้เล่นทดลองอาชีพได้โดยไม่กลัวเสียของ และไม่มีกรณีพิเศษ "โหนดหลุดจากจุดเริ่ม"

---

## 5. Job Level + อาชีพขั้นสูง 10 ทาง (รวม T-023 + T-024)

- ชนะการต่อสู้ได้ **Job XP** = exp ที่ได้ (เข้าอาชีพที่ใช้อยู่ตอนนั้น) · Job Lv 1–10
- **Job Lv 3**: เลือกอาชีพขั้นสูง 1 ใน 2 + โหนดชั้น 1
- **Job Lv 6**: โหนดชั้น 2 (อัปเกรดท่าประจำอาชีพ)
- **Job Lv 10 (Mastered)**: โหนดชั้น 3 + **โบนัสถาวร** ติดตัวทุกอาชีพ
  (Vanguard +10 HP · Marksman +2 ATK · Engineer +2 ARM · Psion +2 TEC · Infiltrator +2 SPD)
- แต่ละชั้นเลือก 1 ใน 2 โหนด — สลับทางอาชีพขั้นสูงที่ Mothership 100 Credits

### รายชื่อ 10 อาชีพขั้นสูง

| อาชีพหลัก | ทาง A | ทาง B |
|---|---|---|
| Vanguard | **Bulwark** — สายรับ: Block / Guard / Counter | **Ravager** — สายบุก: HP ยิ่งน้อยยิ่งตีแรง |
| Marksman | **Deadeye** — สาย Perfect / Critical | **Stormgunner** — สายยิงรัว: หลายช่อง หลายนัด |
| Engineer | **Dronemaster** — สายโดรน | **Fortifier** — สายเกราะพลังงาน / ซ่อมตัวเอง |
| Psion | **Voidcaller** — สาย Plasma Burn / ดาเมจ TEC | **Mindweaver** — สาย Charge + ควบคุมศัตรู |
| Infiltrator | **Phantom** — สายหลบ + Corrosion | **Salvager** — สายกระดาน: Credits / ของดรอป / ก้าวเดิน |

### โหนดแต่ละชั้น (ตัวเลือก 1 / ตัวเลือก 2)

| อาชีพขั้นสูง | ชั้น 1 (Job Lv 3) | ชั้น 2 (Job Lv 6) — อัปเกรดท่า | ชั้น 3 (Job Lv 10) |
|---|---|---|---|
| **Bulwark** | Block +1 ช่อง (2→3) / Guard ได้ Charge คืน 2 | Breach Strike Perfect: Stun 2 ตา / Breach Strike ลดดาเมจที่จะโดนตาถัดไป −50% | HP < 25% → ARM ×2 / Counter Perfect ไม่โดนดาเมจเลย |
| **Ravager** | HP < 50% → ATK +25% / โดนตีแล้วได้ Charge +1 (ตาละครั้ง) | Breach Strike ดูดเลือด 30% ของดาเมจ / Breach Strike +1 ช่อง ดาเมจ ×1.3 | ชนะการต่อสู้ฮีล 30% / HP 1 ครั้งแรกไม่ตาย (ต่อการต่อสู้) |
| **Deadeye** | Critical ×1.5 → ×2 / ช่องเช็คที่เหลือช่องสุดท้าย +15% | Charged Shot Perfect: Stun 1 ตา / Charged Shot ใช้ Charge ฟรี 1 แต้ม | Perfect ได้ Charge +1 / ทุกท่าเพดาน % 95 → 100 |
| **Stormgunner** | Attack +1 ช่อง / ทุกช่องที่ผ่านทำดาเมจเพิ่ม +2 | Charged Shot ยิง 2 นัด (นัดละ ×0.6) / Charged Shot ช่องที่พลาดไม่ลดดาเมจครึ่งแรก | ตาแรกยิงก่อนเสมอ / ทุก 3 ตาได้ Attack ฟรี 1 ครั้ง |
| **Dronemaster** | โดรนดาเมจ TEC×0.6 → ×0.9 / มีโดรนได้ 2 ตัวพร้อมกัน | Deploy Drone ไม่ต้องจ่าย Charge เพิ่ม / โดรนตายแล้วระเบิดดาเมจ TEC | ชนะการต่อสู้ได้ Credits +20% / เริ่มการต่อสู้มีโดรน 1 ตัว |
| **Fortifier** | Kinetic Barrier 10 → 20 / Guard ได้เกราะพลังงาน 8 | Deploy Drone กลายเป็นโดรนโล่: ดูดดาเมจ TEC×0.5 / โดรนฮีลตาละ 3 HP | ARM +20% / เกราะพลังงานแตกแล้วสวน ARM×0.5 |
| **Voidcaller** | Plasma Burn ดาเมจ +50% / Tech Attack +1 ช่อง | Mind Spike ติด Burn 3 ตา / Mind Spike ดาเมจ +1 ต่อ 1 ตา Burn ที่ศัตรูติด | ศัตรูติด Burn ตายแล้วได้ Charge คืน / TEC +20% |
| **Mindweaver** | Charge สูงสุด 3 → 4 / ป้องกันสำเร็จ Perfect ได้ Charge +1 | Mind Spike Perfect: ศัตรูสับสน (ตีตัวเอง 50%) / Mind Spike ลด % ช่องเช็คศัตรู −10% 2 ตา | Charge ละ +15% → +20% / เริ่มการต่อสู้ Charge เต็ม |
| **Phantom** | Dodge สำเร็จได้ Charge +1 / Dodge พลาดโดน ×1.5 → ×1.0 | Twin Shiv ติด Corrosion 3 ตา / Twin Shiv ตี 3 ครั้ง (ครั้งละ ×0.7) | หนีสำเร็จแน่นอนถ้า SPD > ศัตรู / Perfect ทำให้หายตัว: การโจมตีถัดไปของศัตรูพลาดแน่นอน |
| **Salvager** | ของดรอปจากมอนสเตอร์ +25% / ช่องหีบสมบัติได้ 2 ชิ้น | Twin Shiv ขโมยไอเทมแทน Credits ได้ / Twin Shiv ขโมย Credits ×2 | เดินเพิ่ม +1 ก้าว ทุกเทิร์น / ร้านค้าขายคืนได้ 75% แทน 50% |

---

## 6. โครงข้อมูล

> **ของจริงที่ทำแล้ว (T-060 / T-061 / T-063):** ต้นอยู่ที่ `game/passive_tree.gd` (`PassiveTree.NODES` ตำแหน่งเป็น (มุม, รัศมี), ลิงก์เขียนฝั่งเดียว) ·
> แต้มและต้นแยกต่ออาชีพอยู่ใน `PlayerStats` (`trees`, `allocate`, `set_tree`, `reset_tree`) · หน้าจออยู่ที่ `ui/passive_window.gd` (ปุ่ม Passive บนกระดาน) ·
> รีเซ็ตที่เมนูปราสาท · test: `tests/passive_tests.gd` ·
> `mods` ของ Notable / Keystone / สะพานทำงานครบแล้ว (T-062): ระบบต่อสู้อ่านผ่าน `CCBattle.mod(unit, key)` (ส่งเข้ามาทาง `CCBridge.hero_config` คีย์ `mods`),
> `stat_pct.*` (Glass Mind) และ `gold_bonus` (Pickpocket) คิดใน `PlayerStats` · เพิ่ม mod ใหม่ = ใส่ใน `PassiveTree.ACTIVE_MODS` ด้วย ไม่งั้นหน้าจอขึ้น "coming soon"
>
> โค้ดด้านล่างคือร่างตอนออกแบบ

```gdscript
const STAT_LABELS := {"hp": "HP", "atk": "ATK", "def": "ARM", "mag": "TEC", "spd": "SPD"}

# ใน JOBS
"Vanguard": { "desc": "...", "base": {...}, "grow": {...},
              "skill": "breach_strike", "tree_start": "assault_start",
              "board_perk": {"trap_mult": 0.5},
              "suggested": ["assault_hp1", "reinforced_plating", ...],
              "ascend": ["Bulwark", "Ravager"], "mastery": {"hp": 10} },

const PASSIVE_TREE := {
    "assault_start":      {"type": "start", "pos": Vector2(...), "links": [...]},
    "assault_hp1":        {"type": "small", "pos": ..., "links": [...], "stats": {"hp": 5}},
    "reinforced_plating": {"type": "notable", "name": "Reinforced Plating", "pos": ..., "links": [...],
                           "mods": {"check_bonus.block": 10}, "desc": "Block +10% every slot."},
    ...
}

const ASCENDANCIES := {
    "Bulwark": {"job": "Vanguard", "tiers": [
        [{"id": "bw_wall", "mods": {"slots.block": 1}, "desc": "..."}, {...}],   # Job Lv 3
        [...],                                                                  # Job Lv 6
        [...],                                                                  # Job Lv 10
    ]},
}
```

- `stats` = บวกค่าพลังตรง ๆ (รวมใน `PlayerStats.stat()`)
- `mods` = ตัวปรับกติกา เป็นคีย์ชื่อตายตัว เช่น `check_bonus.block`, `crit_mult.attack`, `start_charge`, `slots.attack`, `drone_mult`, `gold_mult`, `trap_mult` — `cc_bridge.gd` ส่งชุด mods ให้ `cc_battle.gd` (engine ยัง pure/seed ได้เหมือนเดิม)
- `PlayerStats` เพิ่ม: `trees` (อาชีพ → Array node id), `job_xp` (อาชีพ → int), `ascend` (อาชีพ → {path, picks}), `passive_points()`, `mods()`

---

## 7. UI

- **หน้าต้น**: วาดด้วย Control (`_draw()` เส้น + ปุ่มวงกลม) ขนาดพอดีหน้าจอ ไม่มีซูม พื้นหลังแนวแผนที่ดาว
  - สีตามแขน 5 สี, ลงแล้ว = สว่าง, ลงได้ = กะพริบเบา ๆ, ลงไม่ได้ = จาง
  - ชี้เมาส์ = tooltip ภาษาง่าย + ตัวเลข, มุมขวาบน "แต้มเหลือ X" + ค่าพลังก่อน/หลัง (แนวเดียวกับ `preview_stat` ใน Equip)
  - ปุ่ม: Confirm · Cancel · ลงตามแนะนำ · (ที่ Mothership) Reset
- **HUD**: มีแต้มเหลือ → ไอคอน "+1 Passive"
- **Mothership**: เมนู `Passive Tree / Reset Tree / Change Job / Ascendancy`
- **หน้าสร้างตัวละคร (T-042)**: เลือก 1 ใน 5 อาชีพ แล้วโชว์ภาพย่อต้นว่าเริ่มแขนไหน

---

## 8. Task breakdown (ต่อจาก T-057 ใน Task_Tracker)

| ID | Category | Task | รายละเอียด | Priority | ขึ้นกับ |
|---|---|---|---|---|---|
| T-058 | Character | 5 อาชีพหลัก (ข้อมูล) | `JOBS` 5 อาชีพ + `STAT_LABELS`, ย้าย Fighter/Mage/Rogue → Vanguard/Psion/Infiltrator, แก้จุดที่อ้างชื่อเดิม (`tile_events.gd`, `player_stats.gd`, test) | High | – |
| T-059 | Battle | ท่าประจำอาชีพใหม่ 2 ท่า | Charged Shot + Deploy Drone (สถานะโดรน) ใน `cc_balance.gd` / `cc_battle.gd` + เปลี่ยนชื่อท่าเดิม 3 ท่า + test | High | T-058 |
| T-060 | Character | ข้อมูล Passive Tree | `PASSIVE_TREE` 51 โหนด (5 แขน + 5 สะพาน + HUB) + validator ใน test (ลิงก์ 2 ทาง, ทุกโหนดเดินถึงจากทุก start) | High | T-058 |
| T-061 | Character | PlayerStats: แต้ม + ต้นแยกต่ออาชีพ | `trees`, `passive_points()`, ลง/คืนโหนด (ต้องติดกัน, คืนได้ถ้าไม่ตัดต้น), `stat()` รวม stats, เปลี่ยนอาชีพสลับต้น | High | T-060 |
| T-062 | Battle | Mods จาก passive เข้าระบบต่อสู้ | `mods()` → `cc_bridge` → `cc_battle` รองรับคีย์ทั้งหมดของ Notable/Keystone/สะพาน + test ทีละโหนด | High | T-059, T-061 |
| T-063 | UI | หน้าจอ Passive Tree | วาดต้น 5 แฉก, tooltip, preview ค่าพลัง, Confirm/Cancel, ลงตามแนะนำ, ไอคอนแต้มเหลือบน HUD | High | T-061 |
| T-064 | Character | Job Level + 10 อาชีพขั้นสูง | Job XP ต่ออาชีพ, ปลดชั้นที่ Lv 3/6/10, `ASCENDANCIES` 10 ทาง × 3 ชั้น × 2 ตัวเลือก (60 โหนด), โบนัส Mastered (แทน T-023, T-024) | Medium | T-062 |
| T-065 | Battle | Balance + simulation | `cc_simulate.gd` รองรับ 5 อาชีพ + บิลด์ `suggested` + Keystone + อาชีพขั้นสูง เทียบอัตราชนะ Lv 5/10/20 | Medium | T-062, T-064 |
| T-066 | Towns | เมนู Mothership ใหม่ | Change Job (สลับต้น), Reset Tree (ฟรีถึง Lv5), เลือก/สลับอาชีพขั้นสูง (100 Credits) | Medium | T-061, T-064 |
| T-067 | Character | ความสามารถอาชีพบนกระดาน | `board_perk` 5 อาชีพ + mods กระดาน (gold_mult, trap_mult, heal_mult, exp_mult, shop_mult) ย้าย Rogue gold จาก `tile_events.gd` มาใช้ระบบนี้ (แทน T-025) | Medium | T-061 |
| T-068 | Art | เปลี่ยนธีมเกมเป็น Sci-Fi | ชื่อในเกมตามตารางข้อ 0 (Mothership, Colony, Credits, ไอเทม, มอนสเตอร์), ฉากกระดาน, สไปรต์ 5 อาชีพ (รวม T-046, T-047) | Medium | – |
| T-069 | System | เซฟ/โหลดข้อมูลอาชีพ | เพิ่ม trees / job_xp / ascend ลงเซฟ (ผูกกับ T-043) | Medium | T-043 |
| T-070 | Battle | ค่าพลัง LCK + ทอยคริ | คีย์ `lck` ใน `JOBS` (base/grow), `PlayerStats.stat`, `cc_bridge` (ฮีโร่ + มอนสเตอร์ ค่าเริ่ม 0), ทอยคริใน `cc_battle.gd` ตอน resolve ท่า (ส่งธง crit เข้า `damage_for`), `CRIT_PER_LCK` / `CRIT_CHANCE_MAX` ใน `cc_balance.gd`, UI + log, โหนดเล็ก +3 LCK บนต้น, test (seed เดิมผลเปลี่ยน → อัปเดต test/replay ที่ล็อกตัวเลข) | High | T-058 |

**Task เดิมที่กระทบ**: T-022 → ยกเลิก (แทนด้วย T-060–T-063) · T-023, T-024 → รวมเป็น T-064 · T-025 → T-067 · T-017 → ย้ายเป็น T-059 · T-004 (อาชีพ 3 แบบ) → ขยายเป็น T-058 · T-046 / T-047 → อยู่ใน T-068

ลำดับแนะนำ: T-058 → T-059 + T-060 (ทำคู่กันได้) → T-061 → T-062 + T-063 (ทำคู่กันได้) → T-067 → T-064 → T-066 → T-065 · T-068 ทำขนานได้ตลอด
