class_name DDMatch
## ให้ AI สองตัวสู้กันจนจบ (ใช้ใน simulation และ test)

const MAX_ACTIONS := 500


static func run_ai_match(config: Dictionary, personalities: Array, ai_seed: int) -> Dictionary:
	var rngs := [RandomNumberGenerator.new(), RandomNumberGenerator.new()]
	rngs[0].seed = ai_seed
	rngs[1].seed = ai_seed ^ 0x9e3779b9
	var s := DDBattle.create_battle(config)
	var n := 0
	while s.phase != "over":
		n += 1
		if n > MAX_ACTIONS:
			push_error("Dice Duel match did not finish")
			break
		var p := DDBattle.actor_of(s)
		var action := DDAi.choose_action(DDView.get_player_view(s, p, false), personalities[p], rngs[p])
		var r := DDBattle.apply_action(s, action)
		if r.error != "":
			push_error("AI made an illegal action: %s %s" % [r.error, action])
			break
		s = r.state
	return s
