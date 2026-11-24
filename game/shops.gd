class_name Shops
extends Node
## ร้านไอเทม (ช่อง Shop) และร้านอาวุธ Smithy (ช่อง Smithy หน้าบ้านข้างปราสาท)
##   await shops.visit_shop(player)
##   await shops.visit_smithy(player)

const CATEGORY_NAMES := {"weapon": "Weapons", "armor": "Armor", "accessory": "Accessories"}

var _state: GameState
var _dialogs: Dialogs
var _equip_window: EquipWindow


func setup(state: GameState, dialogs: Dialogs, equip_window: EquipWindow) -> void:
	_state = state
	_dialogs = dialogs
	_equip_window = equip_window


# ================================================================ ร้านไอเทม
## ขายของใช้ / อาวุธต้องไปซื้อที่ร้าน Smithy
func visit_shop(player: PlayerStats) -> void:
	while true:
		var labels: Array = []
		for it in GameData.ITEM_SHOP_STOCK:
			labels.append("%s  %dG  - %s" % [it, GameData.ITEMS[it].price, GameData.ITEMS[it].desc])
		labels.append("Leave")
		var pick := await _dialogs.choose("Item Shop - You have %d Gold.\n(Weapons & armor are sold at the Smithy by the castle.)" % player.gold, labels)
		if pick >= GameData.ITEM_SHOP_STOCK.size():
			return
		var item: String = GameData.ITEM_SHOP_STOCK[pick]
		var price: int = GameData.ITEMS[item].price
		if player.gold < price:
			await _dialogs.message("Not enough Gold!")
			continue
		if not player.add_item(item):
			await _dialogs.message("Your bag is full!")
			continue
		player.gold -= price
		_state.notify()


# ================================================================ ร้านฝ่าย (FactionShop)
## Concord Armory / Syndicate Market — สต็อกสุ่มใหม่ทุกครั้งที่เข้า · secret = ร้านลับจากอีเวนต์
func visit_faction_shop(player: PlayerStats, shop: String, secret := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stock: Array = FactionShop.roll_stock(player, rng)
	while true:
		var cross := FactionShop.is_cross(player, shop)
		var note := ("You're not one of us. Prices +%d%%, and it'll cost you %d HP." % [roundi((FactionShop.CROSS_PRICE_MULT - 1) * 100), FactionShop.CROSS_HP_COST]) if cross \
			else "Member price: -%d%%." % roundi(FactionShop.RANK_DISCOUNT[FactionShop.rank(player)] * 100)
		if FactionShop.has_coupon(player, shop):
			note += "  Coupon: -%d%% on your next buy." % roundi(FactionShop.COUPON_DISCOUNT * 100)
		var labels: Array = []
		for it in stock:
			labels.append("%s  %dG   %s" % [GameData.display_name(it), FactionShop.price(player, it, shop, FactionShop.has_coupon(player, shop)), GameData.stat_text(it)])
		labels.append("Leave")
		var title := "%s%s - Gold %d   Gear bag %d/%d\n%s" % ["Secret " if secret else "", FactionShop.SHOP_NAMES[shop], player.gold,
			player.gear.size(), GameData.MAX_GEAR, note]
		var pick := await _dialogs.choose(title, labels)
		if pick >= stock.size():
			return
		var item: String = stock[pick]
		var lines := GameData.item_lines(item)
		var warn := "\n\nBuying here marks it: %s" % FactionShop.mark_text(shop) if cross else ""
		var confirm := await _dialogs.choose("Buy %s for %dG?\n%s%s%s" % [GameData.display_name(item), FactionShop.price(player, item, shop, FactionShop.has_coupon(player, shop)),
			GameData.stat_text(item), "\n" + lines if lines != "" else "", warn], ["Buy", "Cancel"])
		if confirm != 0:
			continue
		var r := FactionShop.buy(player, item, shop)
		if not r.ok:
			await _dialogs.message(r.reason)
			continue
		stock.erase(item)
		_state.notify()
		await _dialogs.message("Bought %s for %dG.%s%s" % [GameData.display_name(item), r.price, " (coupon used)" if r.get("coupon", false) else "",
			"\nIt bears the %s mark. You lost %d HP." % ["Syndicate" if shop == "syndicate" else "Concord", FactionShop.CROSS_HP_COST] if r.marked else ""])


## Fabricator: ตีบวก (Overclock) อุปกรณ์ที่สวม/ในกระเป๋า — venue = "concord" / "syndicate" / "smithy"
func visit_fabricator(player: PlayerStats, venue: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while true:
		var gear: Array = player.all_gear().filter(func(it): return Overclock.can_overclock(it))
		if gear.size() > 8: # รายการยาวเกินจอ (648px): ให้เลือกกลุ่มก่อน
			var equipped: Array = gear.filter(func(it): return it == player.weapon or it == player.armor or it == player.accessory)
			var group := await _dialogs.choose("%s - which gear?" % Overclock.VENUES[venue],
				["Equipped (%d)" % equipped.size(), "Gear bag (%d)" % (gear.size() - equipped.size()), "Leave"])
			if group == 2:
				return
			gear = equipped if group == 0 else gear.filter(func(it): return not equipped.has(it))
		var labels: Array = []
		for it in gear:
			labels.append("%s  ->  +%d   %d%%   %dG" % [GameData.display_name(it), ItemDB.plus_of(it) + 1,
				Overclock.chance(player, it, venue), Overclock.cost(it)])
		labels.append("Leave")
		var bonus := ""
		if venue != "smithy":
			bonus = "  (%s: %+d%% chance)" % ["your faction" if player.faction() == venue else "rival faction",
				Overclock.VENUE_BONUS if player.faction() == venue else -Overclock.VENUE_BONUS]
		var pick := await _dialogs.choose("%s - Gold %d%s\nFail = drops 1 level. %s: %d" % [Overclock.VENUES[venue], player.gold, bonus,
			Overclock.STABILIZER, player.items.count(Overclock.STABILIZER)], labels)
		if pick >= gear.size():
			return
		var item: String = gear[pick]
		var opts := ["Overclock", "Cancel"]
		if player.items.has(Overclock.STABILIZER) and ItemDB.plus_of(item) > 0:
			opts = ["Overclock", "Overclock with %s" % Overclock.STABILIZER, "Cancel"]
		var confirm := await _dialogs.choose("Overclock %s to +%d?\n%d%% success, costs %dG.\nOn failure: %s." % [GameData.display_name(item),
			ItemDB.plus_of(item) + 1, Overclock.chance(player, item, venue), Overclock.cost(item),
			"stays +0" if ItemDB.plus_of(item) == 0 else "drops to +%d" % (ItemDB.plus_of(item) - 1)], opts)
		if confirm == opts.size() - 1:
			continue
		var r := Overclock.attempt(player, item, venue, confirm == 1, rng)
		_state.notify()
		if not r.ok:
			await _dialogs.message(r.reason)
		elif r.success:
			await _dialogs.message("SUCCESS! %s\n%s" % [GameData.display_name(r.id), GameData.stat_text(r.id)])
		else:
			await _dialogs.message("The Fabricator sparks and whines... failed.\n%s%s" % [GameData.display_name(r.id),
				" (the Stabilizer held the level)" if r.stabilized else (" dropped to +%d" % r.plus if r.old_plus > 0 else " (still +0)")])


## Freeport Exchange — ซื้อด้วย Scrip
func visit_exchange(player: PlayerStats) -> void:
	var keys: Array = FactionShop.EXCHANGE_STOCK.keys()
	while true:
		var labels: Array = []
		for k in keys:
			labels.append("%s  %d Scrip" % [FactionShop.exchange_name(k), FactionShop.exchange_price(player, k)])
		labels.append("Leave")
		var pick := await _dialogs.choose("Freeport Exchange - Scrip %d   Renown %d\n\"Everyone's welcome. Everyone pays.\"" % [player.scrip, player.renown], labels)
		if pick >= keys.size():
			return
		var r := FactionShop.buy_exchange(player, keys[pick])
		_state.notify()
		await _dialogs.message(r.reason if not r.ok else "Bought %s for %d Scrip." % [FactionShop.exchange_name(keys[pick]), r.price])


# ================================================================ ร้านอาวุธ (Smithy)
func visit_smithy(player: PlayerStats) -> void:
	var text := "Smithy \"Iron & Ember\"\n\"Welcome, traveler! Gold for steel - fair and square.\""
	while true:
		var pick := await _dialogs.choose("%s\nYou have %d Gold." % [text, player.gold], ["Buy", "Sell", "Equip", "Overclock", "Leave"])
		match pick:
			0:
				await _smithy_buy(player)
			1:
				await _smithy_sell(player)
			2:
				await _equip_window.open(player)
				_state.notify()
			3:
				await visit_fabricator(player, "smithy")
			_:
				return
		text = "Smithy \"Iron & Ember\"\n\"Anything else?\""


func _smithy_buy(player: PlayerStats) -> void:
	var cats: Array = GameData.SMITHY_STOCK.keys()
	while true:
		var cat_labels: Array = []
		for c in cats:
			cat_labels.append(CATEGORY_NAMES[c])
		cat_labels.append("Skill Gems")
		cat_labels.append("Back")
		var c_pick := await _dialogs.choose("What are you looking for? (Gold %d)" % player.gold, cat_labels)
		if c_pick == cats.size():
			await _smithy_buy_gems(player)
			continue
		if c_pick > cats.size():
			return
		await _smithy_buy_list(player, cats[c_pick])


## Skill Gem: ท่าที่ถอดเปลี่ยนได้ 2 ช่อง (ซื้อแล้วถ้ามีช่องว่างจะใส่ให้เลย ไม่งั้นเข้ากระเป๋า gem)
func _smithy_buy_gems(player: PlayerStats) -> void:
	var stock: Array = CCBalance.GEMS.keys().filter(func(g): return CCBalance.GEMS[g].price > 0)
	while true:
		var labels: Array = []
		for g in stock:
			var req := CCBalance.gem_requirement_text(g)
			labels.append("%s  %dG%s%s" % [GameData.gem_name(g), CCBalance.GEMS[g].price, "   (%s)" % req if req != "" else "", "   (owned)" if player.owns_gem(g) else ""])
		labels.append("Back")
		var pick := await _dialogs.choose("Skill Gems - Gold %d\nGems are moves you can swap in the Equip window (2 slots)." % player.gold, labels)
		if pick >= stock.size():
			return
		var gem: String = stock[pick]
		var price: int = CCBalance.GEMS[gem].price
		if player.owns_gem(gem):
			await _dialogs.message("You already have %s." % GameData.gem_name(gem))
			continue
		if player.gold < price:
			await _dialogs.message("Not enough Gold! (%s costs %dG, you have %dG)" % [GameData.gem_name(gem), price, player.gold])
			continue
		var confirm := await _dialogs.choose("Buy %s for %dG?\n%s" % [GameData.gem_name(gem), price, CCBalance.GEMS[gem].desc], ["Buy", "Cancel"])
		if confirm != 0:
			continue
		player.gold -= price
		player.add_gem(gem)
		_state.notify()
		await _dialogs.message("You got %s! %s" % [GameData.gem_name(gem),
			"It's socketed." if player.gems.has(gem) else "It's in your gem bag - swap it in at Equip."])


func _smithy_buy_list(player: PlayerStats, cat: String) -> void:
	var stock: Array = GameData.SMITHY_STOCK[cat]
	while true:
		var labels: Array = []
		for it in stock:
			labels.append("%s  %dG   %s%s" % [it, GameData.ITEMS[it].price, GameData.stat_text(it), "   (owned)" if player.owns(it) else ""])
		labels.append("Back")
		var pick := await _dialogs.choose("%s - Gold %d   Gear bag %d/%d" % [CATEGORY_NAMES[cat], player.gold, player.gear.size(), GameData.MAX_GEAR], labels)
		if pick >= stock.size():
			return
		var item: String = stock[pick]
		var price: int = GameData.ITEMS[item].price
		if player.gold < price:
			await _dialogs.message("Not enough Gold! (%s costs %dG, you have %dG)" % [item, price, player.gold])
			continue
		if player.gear.size() >= GameData.MAX_GEAR:
			await _dialogs.message("Your gear bag is full! Sell something first.")
			continue
		var confirm := await _dialogs.choose("Buy %s for %dG?\n%s\nIf equipped: %s" % [item, price, GameData.ITEMS[item].desc, _compare_text(player, item)], ["Buy", "Cancel"])
		if confirm != 0:
			continue
		player.gold -= price
		player.add_gear(item)
		_state.notify()
		var eq := await _dialogs.choose("You bought %s! Equip it now?" % item, ["Equip now", "Keep in gear bag"])
		if eq == 0:
			var old := player.equip(item)
			_state.notify()
			await _dialogs.message("Equipped %s.%s" % [item, " (%s went to your gear bag)" % old if old != "" else ""])


func _smithy_sell(player: PlayerStats) -> void:
	while true:
		if player.gear.is_empty():
			await _dialogs.message("You have no spare gear to sell.\n(Unequip something in the Equip window first.)")
			return
		var labels: Array = []
		for it in player.gear:
			labels.append("%s  -> %dG   %s" % [GameData.display_name(it), GameData.sell_price(it), GameData.stat_text(it)])
		labels.append("Back")
		var pick := await _dialogs.choose("Sell which gear? (I pay half price)  Gold %d" % player.gold, labels)
		if pick >= player.gear.size():
			return
		var item: String = player.gear[pick]
		var value := GameData.sell_price(item)
		var lines := GameData.item_lines(item)
		var confirm := await _dialogs.choose("Sell %s for %dG?%s" % [GameData.display_name(item), value, "\n" + lines if lines != "" else ""], ["Sell", "Cancel"])
		if confirm != 0:
			continue
		player.gear.remove_at(pick)
		player.gold += value
		_state.notify()


## เทียบค่าพลังถ้าสวม item เช่น "ATK 6->12, SPD 6->5"
func _compare_text(player: PlayerStats, item: String) -> String:
	var parts := PackedStringArray()
	for k in GameData.STAT_KEYS:
		var cur := player.stat(k)
		var nv := player.preview_stat(k, item)
		if nv != cur:
			parts.append("%s %d→%d" % [GameData.stat_label(k), cur, nv])
	return ", ".join(parts) if not parts.is_empty() else "no stat change"
