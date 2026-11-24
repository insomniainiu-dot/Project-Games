class_name FactionShop
## ร้านฝ่าย (docs/faction_event_design.md ข้อ 2–3) — ตรรกะล้วน ไม่แตะ UI (UI อยู่ที่ Shops)
##   Concord Armory / Syndicate Market: ขายอุปกรณ์ Rare/Epic ด้วย Credits
##     ฝ่ายเดียวกัน = ลดตามระดับฝ่าย · ฝ่ายตรงข้าม = แพงขึ้น + จ่าย HP + ของติด "ตรา"
##   Freeport Exchange: ขายของด้วย Scrip ทุกฝ่ายซื้อได้ราคาเดียว (Renown สูงได้ส่วนลด)

const SHOP_NAMES := {"concord": "Concord Armory", "syndicate": "Syndicate Market", "freeport": "Freeport Exchange"}

# ---------------------------------------------------------------- ราคา
## ระดับฝ่าย → ส่วนลด (ระดับ 1/2/3) · Karma ที่ต้องมีอยู่ใน rank()
const RANK_DISCOUNT := {1: 0.10, 2: 0.15, 3: 0.20}
const RANK_KARMA := [40, 80] ## |Karma| ถึงเท่านี้ = ระดับ 2 / 3
const CROSS_PRICE_MULT := 1.25 ## ซื้อร้านฝ่ายตรงข้าม แพงขึ้น 25%
const CROSS_HP_COST := 5 ## และจ่าย HP เท่านี้ (ไม่ทำให้ตาย)
const COUPON_DISCOUNT := 0.25 ## คูปองจากอีเวนต์: ลดเพิ่ม 25% ใช้ครั้งเดียว

# ---------------------------------------------------------------- ตราข้ามฝ่าย (ItemDB record "mark")
const MARK_ATTACK_MULT := 1.1 ## ของที่มีตรา: Attack ดาเมจ ×1.1
const CONCORD_MARK_SPD := 1 ## ตรา Concord เพิ่ม SPD +1 ด้วย ("ตีแรงเร็วขึ้น")
const MARK_KARMA := 2 ## ทุกครั้งที่เริ่มสู้: ตรา Concord Karma +2 · ตรา Syndicate Karma −2

# ---------------------------------------------------------------- สต็อก
const STOCK_SIZE := 4
## tier ของสต็อกตามเลเวล: [เลเวลขั้นต่ำ, {tier: น้ำหนัก}]
const STOCK_TIERS := [
	[1, {"rare": 100}],
	[5, {"rare": 80, "epic": 20}],
	[10, {"rare": 60, "epic": 40}],
]
## Freeport Exchange: ราคาเป็น Scrip · คีย์ = ไอเทมใน GameData.ITEMS หรือ Skill Gem ใน CCBalance.GEMS
const EXCHANGE_STOCK := {
	"Sedative Dart": 2, "Big Medkit": 2, "Smoke Bomb": 1, "Stim Shot": 2,
	"charged_shot": 6, "twin_stab": 6, "deploy_drone": 7, "fireball": 7, "heavy_blow": 6,
}
const EXCHANGE_RENOWN_DISCOUNT := 20 ## Renown ถึงเท่านี้ ลด 1 Scrip ต่อชิ้น (ขั้นต่ำ 1)


## ระดับในฝ่ายของผู้เล่น 1..3
static func rank(player: PlayerStats) -> int:
	var k := absi(player.karma) if player.syndicate else player.karma
	if player.syndicate and player.karma >= 0:
		k = 0 # Karma 0–9 ระหว่างรอกลับ Concord นับเป็นระดับ 1
	var r := 1
	for t in RANK_KARMA:
		if k >= t:
			r += 1
	return r


static func is_cross(player: PlayerStats, shop: String) -> bool:
	return player.faction() != shop


## ราคาที่ต้องจ่าย (Credits) — coupon = ใช้คูปองไหม
static func price(player: PlayerStats, item_id: String, shop: String, coupon := false) -> int:
	var p := float(GameData.item(item_id).get("price", 0))
	if is_cross(player, shop):
		p *= CROSS_PRICE_MULT
	else:
		p *= 1.0 - float(RANK_DISCOUNT[rank(player)])
	if coupon:
		p *= 1.0 - COUPON_DISCOUNT
	return maxi(1, roundi(p))


static func has_coupon(player: PlayerStats, shop: String) -> bool:
	return int(player.coupons.get(shop, 0)) > 0


## สุ่มสต็อกร้าน (Rare/Epic ตามเลเวล ฐานจากของใน Smithy)
static func roll_stock(player: PlayerStats, rng: RandomNumberGenerator) -> Array:
	var weights: Dictionary = STOCK_TIERS[0][1]
	for row in STOCK_TIERS:
		if player.level >= int(row[0]):
			weights = row[1]
	var bases := []
	for cat in GameData.SMITHY_STOCK:
		bases.append_array(GameData.SMITHY_STOCK[cat])
	var out := []
	for i in STOCK_SIZE:
		out.append(ItemDB.create(bases[rng.randi_range(0, bases.size() - 1)], CCBattle._pick(weights, rng), rng))
	return out


## ซื้อ: {"ok", "reason", "price", "marked"} — สำเร็จแล้วของเข้ากระเป๋าอุปกรณ์
static func buy(player: PlayerStats, item_id: String, shop: String) -> Dictionary:
	var coupon := has_coupon(player, shop)
	var cost := price(player, item_id, shop, coupon)
	if player.gold < cost:
		return {"ok": false, "reason": "Not enough Gold (%d needed)." % cost, "price": cost, "marked": false}
	if player.gear.size() >= GameData.MAX_GEAR:
		return {"ok": false, "reason": "Your gear bag is full.", "price": cost, "marked": false}
	player.gold -= cost
	if coupon:
		player.coupons[shop] = int(player.coupons[shop]) - 1
	var cross := is_cross(player, shop)
	if cross:
		player.hp = maxi(1, player.hp - CROSS_HP_COST)
		ItemDB.set_mark(item_id, shop)
	player.add_gear(item_id)
	return {"ok": true, "reason": "", "price": cost, "marked": cross, "coupon": coupon}


static func mark_text(mark: String) -> String:
	var label: String = "Concord" if mark == "concord" else "Syndicate"
	return "%s Mark: Attack x%s%s, Karma %+d per battle, barred from %s towns" % [label, MARK_ATTACK_MULT,
		", SPD +%d" % CONCORD_MARK_SPD if mark == "concord" else "", MARK_KARMA if mark == "concord" else -MARK_KARMA,
		"Syndicate" if mark == "concord" else "Concord"]


# ---------------------------------------------------------------- Freeport Exchange
static func exchange_price(player: PlayerStats, key: String) -> int:
	var p: int = EXCHANGE_STOCK[key]
	if player.renown >= EXCHANGE_RENOWN_DISCOUNT:
		p -= 1
	return maxi(1, p)


static func exchange_name(key: String) -> String:
	return GameData.gem_name(key) + " (Skill Gem)" if CCBalance.GEMS.has(key) else key


static func buy_exchange(player: PlayerStats, key: String) -> Dictionary:
	var cost := exchange_price(player, key)
	if player.scrip < cost:
		return {"ok": false, "reason": "Not enough Scrip (%d needed)." % cost}
	if CCBalance.GEMS.has(key):
		if player.owns_gem(key):
			return {"ok": false, "reason": "You already have that gem."}
		player.add_gem(key)
	elif not player.add_item(key):
		return {"ok": false, "reason": "Your bag is full."}
	player.scrip -= cost
	return {"ok": true, "reason": "", "price": cost}
