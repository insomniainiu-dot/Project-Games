class_name Overclock
## ตีบวกอุปกรณ์ +1..+5 ด้วยเครื่อง Fabricator (docs/faction_event_design.md ข้อ 4) — ตรรกะล้วน ไม่แตะ UI
##   ล้มเหลว = ลดลง 1 ระดับ (ตีจาก +0 ล้มเหลวเสียแค่เงิน) · ของไม่พัง
##   Phase Stabilizer (ไอเทม) ใช้ก่อนตี: ล้มเหลวครั้งนั้นไม่ลดระดับ
##   ตีที่ร้านฝ่ายเดียวกัน +15% โอกาส · ร้านฝ่ายตรงข้าม −15% · Smithy (กลาง) ไม่มีผล
##   var r := Overclock.attempt(player, item_id, "concord", use_stabilizer, rng)

const MAX_PLUS := 5
const CHANCE := [85, 70, 55, 40, 25] ## โอกาสสำเร็จ (%) เมื่อตีไป +1 .. +5
const COST_PCT := [20, 30, 40, 50, 60] ## ค่าตี (% ของราคาไอเทมตาม tier)
const MIN_COST := 10
const STAT_PCT := 10 ## ค่าพลังบวกทุกตัว +10% ต่อระดับ (ปัดขึ้น อย่างน้อย +1 ต่อระดับ) — ใช้ใน ItemDB.data
const PRICE_PCT_PER_PLUS := 10 ## ราคาขาย +10% ต่อระดับ
const VENUE_BONUS := 15 ## ร้านฝ่ายเดียวกัน + / ฝ่ายตรงข้าม −
const CHANCE_MIN := 5
const CHANCE_MAX := 95
const STABILIZER := "Phase Stabilizer"
const VENUES := {"concord": "Concord Fabricator", "syndicate": "Syndicate Fabricator", "smithy": "Smithy Fabricator"}


static func can_overclock(item_id: String) -> bool:
	var d := GameData.item(item_id)
	return d.get("type", "") in ["weapon", "armor", "accessory"] and ItemDB.plus_of(item_id) < MAX_PLUS


## โอกาสสำเร็จ (%) ของการตีครั้งถัดไป ที่ venue ("concord" / "syndicate" / "smithy")
static func chance(player: PlayerStats, item_id: String, venue: String) -> int:
	var c: int = CHANCE[mini(ItemDB.plus_of(item_id), MAX_PLUS - 1)]
	if venue == "concord" or venue == "syndicate":
		c += VENUE_BONUS if player.faction() == venue else -VENUE_BONUS
	return clampi(c, CHANCE_MIN, CHANCE_MAX)


static func cost(item_id: String) -> int:
	var pct: int = COST_PCT[mini(ItemDB.plus_of(item_id), MAX_PLUS - 1)]
	return maxi(MIN_COST, roundi(ItemDB.base_price(item_id) * pct / 100.0))


## ระดับหลังล้มเหลว
static func fail_plus(plus: int, stabilized: bool) -> int:
	return plus if stabilized else maxi(0, plus - 1)


## ตี: {"ok", "reason", "success", "id" (id ใหม่ถ้าถูกแปลงเป็น instance), "plus", "cost", "stabilized"}
## สำเร็จ/ล้มเหลวแล้ว id ในช่องสวม/กระเป๋าของผู้เล่นถูกเปลี่ยนให้แล้ว
static func attempt(player: PlayerStats, item_id: String, venue: String, use_stabilizer: bool, rng: RandomNumberGenerator) -> Dictionary:
	if not player.all_gear().has(item_id):
		return {"ok": false, "reason": "You don't have that item."}
	if not can_overclock(item_id):
		return {"ok": false, "reason": "Already at +%d - it can't go higher." % MAX_PLUS}
	var price := cost(item_id)
	if player.gold < price:
		return {"ok": false, "reason": "Not enough Gold (%d needed)." % price}
	var stab := use_stabilizer and player.items.has(STABILIZER)
	var c := chance(player, item_id, venue)
	player.gold -= price
	if stab:
		player.items.erase(STABILIZER)
	var id := ItemDB.promote(item_id)
	player.replace_gear(item_id, id)
	var plus := ItemDB.plus_of(id)
	var success := rng.randi_range(1, 100) <= c
	var new_plus := plus + 1 if success else fail_plus(plus, stab)
	ItemDB.set_plus(id, new_plus)
	player._clamp_hp() # HP สูงสุดอาจเปลี่ยน
	return {"ok": true, "reason": "", "success": success, "id": id, "plus": new_plus, "old_plus": plus, "cost": price,
		"stabilized": stab, "chance": c}
