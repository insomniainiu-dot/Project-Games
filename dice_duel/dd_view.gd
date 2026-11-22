class_name DDView
## get_player_view: state ที่ส่งให้ UI/AI ของผู้เล่นแต่ละคน
## ซ่อน: ผลทอยของอีกฝ่าย, ท่าที่อีกฝ่ายวาง (ก่อนเปิด), ผล Shadow Read ของอีกฝ่าย
## และลบข้อมูลลับเดียวกันออกจาก event log
##
## PlayerView = {
##   "player_id", "round", "max_rounds", "phase", "attacker", "is_my_turn", "winner",
##   "me": {name, job, stats, hp, max_hp, focus, swipe_used, shadow_read_used, free_reroll_used,
##          dice: [{die, face_index, face}], peek: null/{die_id, face}, placement},
##   "opponent": {name, job, stats, hp, max_hp, focus, swipe_used, dice: [die build ไม่มีผลทอย], placed_count: -1/n},
##   "reveal": ระหว่างเฟส swipe = เปิดเต๋ารอบนี้, ไม่งั้น = ผลรอบล่าสุด,
##   "log": [...] }


static func redact_event(e: Dictionary, viewer: int) -> Dictionary:
	if e.has("visible_to") and e.visible_to != viewer:
		return {}
	match e.t:
		"rolled":
			return e if e.player == viewer else {"t": "rolled", "player": e.player, "dice": []}
		"rerolled":
			return e if e.player == viewer else {"t": "rerolled", "player": e.player, "die_id": e.die_id, "free": e.free}
		"shadow_read":
			return e if e.player == viewer else {"t": "shadow_read", "player": e.player}
		"placed":
			return e if e.player == viewer else {"t": "placed", "player": e.player, "count": e.count}
	return e


## include_log = false ใช้ตอน simulation (เร็วขึ้นมาก AI ไม่ได้ใช้ log)
static func get_player_view(state: Dictionary, player_id: int, include_log := true) -> Dictionary:
	var me: Dictionary = state.fighters[player_id]
	var opp_id := 1 - player_id
	var opp: Dictionary = state.fighters[opp_id]

	var peek = null
	if me.peek != null:
		var pd := DDBattle.find_die(opp.character, me.peek.die_id)
		peek = {"die_id": me.peek.die_id, "face": pd.faces[me.peek.face_index]}

	var my_dice := []
	for r in me.rolled:
		var die := DDBattle.find_die(me.character, r.die_id)
		my_dice.append({"die": die, "face_index": r.face_index, "face": die.faces[r.face_index]})

	var events := []
	if include_log:
		for e in state.log:
			var x := redact_event(e, player_id)
			if not x.is_empty():
				events.append(x)

	var view := {
		"player_id": player_id,
		"round": state.round,
		"max_rounds": DDBalance.MAX_ROUNDS,
		"phase": state.phase,
		"attacker": state.attacker,
		"is_my_turn": DDBattle.actor_of(state) == player_id,
		"winner": state.winner,
		"me": {
			"name": me.character.name, "job": me.character.job, "stats": me.character.stats,
			"hp": me.hp, "max_hp": me.max_hp, "focus": me.focus, "swipe_used": me.swipe_used,
			"shadow_read_used": me.shadow_read_used, "free_reroll_used": me.free_reroll_used,
			"dice": my_dice, "peek": peek, "placement": state.placements[player_id],
		},
		"opponent": {
			"name": opp.character.name, "job": opp.character.job, "stats": opp.character.stats,
			"hp": opp.hp, "max_hp": opp.max_hp, "focus": opp.focus, "swipe_used": opp.swipe_used,
			"dice": opp.character.dice,
			"placed_count": state.placements[opp_id].dice.size() if state.placements[opp_id] != null else -1,
		},
		"reveal": state.reveal,
		"log": events,
	}
	return view.duplicate(true) # ไม่ให้ UI ถือ reference ของ state จริง
