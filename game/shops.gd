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


# ================================================================ ร้านอาวุธ (Smithy)
func visit_smithy(player: PlayerStats) -> void:
	var text := "Smithy \"Iron & Ember\"\n\"Welcome, traveler! Gold for steel - fair and square.\""
	while true:
		var pick := await _dialogs.choose("%s\nYou have %d Gold." % [text, player.gold], ["Buy", "Sell", "Equip", "Leave"])
		match pick:
			0:
				await _smithy_buy(player)
			1:
				await _smithy_sell(player)
			2:
				await _equip_window.open(player)
				_state.notify()
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
			labels.append("%s  %dG%s" % [GameData.gem_name(g), CCBalance.GEMS[g].price, "   (owned)" if player.owns_gem(g) else ""])
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
