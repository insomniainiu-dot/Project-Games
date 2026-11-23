class_name PassiveTree
## Passive Tree ต้นเดียวใช้ร่วมทุกอาชีพ (ดู docs/class_passive_design.md)
## รูปดาว 5 แฉก: แฉกละ 9 โหนด (จุดเริ่ม, โหนดเล็ก 4, Notable 3, Keystone 1) + สะพาน 5 + HUB 1 = 51 โหนด
##
## เพิ่ม-แก้โหนดได้ที่ NODES ที่เดียว:
##   type  : "start" / "small" / "notable" / "keystone" / "bridge" / "hub"
##   at    : ตำแหน่งแบบ (มุมองศา, รัศมี) — มุม -90 = บนสุด, หมุนตามเข็มนาฬิกา, รัศมี 0 = กลางจอ ~1 = ขอบ
##   links : โหนดที่ติดกัน (เขียนฝั่งเดียวพอ ระบบทำเป็น 2 ทางให้เอง)
##   stats : บวกค่าพลังตรง ๆ (ใช้ทันที)
##   mods  : ตัวปรับกติกาการต่อสู้/กระดาน — ยังไม่ทำงานจนกว่าจะทำ T-062 (ดู ACTIVE_MODS)
##   job   : (เฉพาะ start) จุดเริ่มของอาชีพไหน — ลงแต้มที่จุดเริ่มของอาชีพอื่นไม่ได้

## mods ที่ระบบต่อสู้/กระดานอ่านแล้ว — โหนดที่มี mod นอกรายการนี้ UI จะขึ้นว่า "coming soon"
## ระบบต่อสู้อ่านผ่าน CCBattle.mod(unit, key) · stat_pct.* และ gold_bonus อ่านใน PlayerStats
const ACTIVE_MODS: Array[String] = [
	"check_bonus.block", "guard_heal_pct", "crit_mult.attack", "block_cut", "no_dodge",
	"first_slot_bonus.attack", "perfect_armor_pierce", "first_strike", "long_skill_mult", "short_skill_mult",
	"drone_turns", "regen", "start_barrier", "drone_mult", "attack_mult",
	"start_focus", "burn_turns", "check_bonus.block_tec", "stat_pct.mag", "stat_pct.hp",
	"dodge_penalty", "gold_bonus", "reroll_first_fail", "perfect_mult", "imperfect_mult",
	"counter_mult", "attack_uses_avg_tec", "drone_check_bonus", "poison_bonus", "first_turn_attack_slots",
]

const ARM_COLORS := {
	"assault": Color(0.95, 0.35, 0.3),
	"precision": Color(1.0, 0.62, 0.2),
	"machine": Color(0.95, 0.85, 0.25),
	"psi": Color(0.7, 0.45, 1.0),
	"shadow": Color(0.35, 0.85, 0.45),
	"bridge": Color(0.55, 0.85, 0.95),
	"hub": Color(0.92, 0.92, 0.92),
}

const NODES := {
	"hub": {"type": "hub", "arm": "hub", "name": "Core Matrix", "at": Vector2(0, 0), "links": [],
		"stats": {"hp": 3, "atk": 1, "def": 1, "mag": 1, "spd": 1, "lck": 1}},

	# ------------------------------------------------ Assault (Vanguard) มุม -90
	"assault_start": {"type": "start", "arm": "assault", "job": "Vanguard", "name": "Vanguard", "at": Vector2(-90, 0.40),
		"links": ["assault_in", "assault_l", "assault_r"]},
	"assault_in": {"type": "small", "arm": "assault", "at": Vector2(-90, 0.22), "links": ["hub"], "stats": {"hp": 5}},
	"assault_l": {"type": "small", "arm": "assault", "at": Vector2(-101, 0.55), "links": ["reinforced_plating"], "stats": {"atk": 2}},
	"assault_r": {"type": "small", "arm": "assault", "at": Vector2(-79, 0.55), "links": ["adrenal_surge"], "stats": {"def": 2}},
	"reinforced_plating": {"type": "notable", "arm": "assault", "name": "Reinforced Plating", "at": Vector2(-105, 0.71), "links": ["assault_out"],
		"mods": {"check_bonus.block": 10}, "desc": "Block: +10% chance on every slot."},
	"adrenal_surge": {"type": "notable", "arm": "assault", "name": "Adrenal Surge", "at": Vector2(-75, 0.71), "links": ["assault_out"],
		"mods": {"guard_heal_pct": 10}, "desc": "Guard also heals 10% of max HP."},
	"assault_out": {"type": "small", "arm": "assault", "at": Vector2(-90, 0.79), "links": ["breacher"], "stats": {"hp": 5}},
	"breacher": {"type": "notable", "arm": "assault", "name": "Breacher", "at": Vector2(-90, 0.91), "links": ["juggernaut"],
		"mods": {"crit_mult.attack": 1.8}, "desc": "Attack critical hits: x1.5 -> x1.8."},
	"juggernaut": {"type": "keystone", "arm": "assault", "name": "Juggernaut", "at": Vector2(-90, 1.03), "links": [],
		"mods": {"block_cut": 0.4, "no_dodge": true}, "desc": "Block cuts 40% per slot (was 30%).\nBUT you can't Dodge."},

	# ------------------------------------------------ Precision (Marksman) มุม -18
	"precision_start": {"type": "start", "arm": "precision", "job": "Marksman", "name": "Marksman", "at": Vector2(-18, 0.40),
		"links": ["precision_in", "precision_l", "precision_r"]},
	"precision_in": {"type": "small", "arm": "precision", "at": Vector2(-18, 0.22), "links": ["hub"], "stats": {"atk": 2}},
	"precision_l": {"type": "small", "arm": "precision", "at": Vector2(-29, 0.55), "links": ["steady_aim"], "stats": {"spd": 2}},
	"precision_r": {"type": "small", "arm": "precision", "at": Vector2(-7, 0.55), "links": ["weak_point"], "stats": {"atk": 2}},
	"steady_aim": {"type": "notable", "arm": "precision", "name": "Steady Aim", "at": Vector2(-33, 0.71), "links": ["precision_out"],
		"mods": {"first_slot_bonus.attack": 20}, "desc": "Attack: the first slot gets +20% chance."},
	"weak_point": {"type": "notable", "arm": "precision", "name": "Weak Point", "at": Vector2(-3, 0.71), "links": ["precision_out"],
		"mods": {"perfect_armor_pierce": 0.25}, "desc": "Any Perfect hit ignores 25% of the target's ARM."},
	"precision_out": {"type": "small", "arm": "precision", "at": Vector2(-18, 0.79), "links": ["quick_draw"], "stats": {"lck": 3}},
	"quick_draw": {"type": "notable", "arm": "precision", "name": "Quick Draw", "at": Vector2(-18, 0.91), "links": ["one_shot"],
		"mods": {"first_strike": true}, "desc": "Round 1 of every battle: you always act first."},
	"one_shot": {"type": "keystone", "arm": "precision", "name": "One Shot", "at": Vector2(-18, 1.03), "links": [],
		"mods": {"long_skill_mult": 1.4, "short_skill_mult": 0.6}, "desc": "Moves with 4+ slots deal x1.4 damage.\nBUT moves with 1-2 slots deal x0.6."},

	# ------------------------------------------------ Machine (Engineer) มุม 54
	"machine_start": {"type": "start", "arm": "machine", "job": "Engineer", "name": "Engineer", "at": Vector2(54, 0.40),
		"links": ["machine_in", "machine_l", "machine_r"]},
	"machine_in": {"type": "small", "arm": "machine", "at": Vector2(54, 0.22), "links": ["hub"], "stats": {"mag": 2}},
	"machine_l": {"type": "small", "arm": "machine", "at": Vector2(43, 0.55), "links": ["overclocked_drones"], "stats": {"def": 2}},
	"machine_r": {"type": "small", "arm": "machine", "at": Vector2(65, 0.55), "links": ["auto_repair"], "stats": {"mag": 2}},
	"overclocked_drones": {"type": "notable", "arm": "machine", "name": "Overclocked Drones", "at": Vector2(39, 0.71), "links": ["machine_out"],
		"mods": {"drone_turns": 1}, "desc": "Drones last 1 more turn."},
	"auto_repair": {"type": "notable", "arm": "machine", "name": "Auto-Repair", "at": Vector2(69, 0.71), "links": ["machine_out"],
		"mods": {"regen": 2}, "desc": "Heal 2 HP at the start of each of your turns."},
	"machine_out": {"type": "small", "arm": "machine", "at": Vector2(54, 0.79), "links": ["kinetic_barrier"], "stats": {"def": 2}},
	"kinetic_barrier": {"type": "notable", "arm": "machine", "name": "Kinetic Barrier", "at": Vector2(54, 0.91), "links": ["full_automation"],
		"mods": {"start_barrier": 10}, "desc": "Start each battle with a barrier that absorbs 10 damage."},
	"full_automation": {"type": "keystone", "arm": "machine", "name": "Full Automation", "at": Vector2(54, 1.03), "links": [],
		"mods": {"drone_mult": 2.0, "attack_mult": 0.6}, "desc": "Drone damage x2.\nBUT Attack deals x0.6."},

	# ------------------------------------------------ Psi (Psion) มุม 126
	"psi_start": {"type": "start", "arm": "psi", "job": "Psion", "name": "Psion", "at": Vector2(126, 0.40),
		"links": ["psi_in", "psi_l", "psi_r"]},
	"psi_in": {"type": "small", "arm": "psi", "at": Vector2(126, 0.22), "links": ["hub"], "stats": {"mag": 2}},
	"psi_l": {"type": "small", "arm": "psi", "at": Vector2(115, 0.55), "links": ["deep_focus"], "stats": {"hp": 5}},
	"psi_r": {"type": "small", "arm": "psi", "at": Vector2(137, 0.55), "links": ["plasma_feed"], "stats": {"mag": 2}},
	"deep_focus": {"type": "notable", "arm": "psi", "name": "Deep Focus", "at": Vector2(111, 0.71), "links": ["psi_out"],
		"mods": {"start_focus": 1}, "desc": "Start each battle with +1 Focus."},
	"plasma_feed": {"type": "notable", "arm": "psi", "name": "Plasma Feed", "at": Vector2(141, 0.71), "links": ["psi_out"],
		"mods": {"burn_turns": 1}, "desc": "Your burns last 1 more turn."},
	"psi_out": {"type": "small", "arm": "psi", "at": Vector2(126, 0.79), "links": ["psi_shield"], "stats": {"mag": 2}},
	"psi_shield": {"type": "notable", "arm": "psi", "name": "Psi Shield", "at": Vector2(126, 0.91), "links": ["glass_mind"],
		"mods": {"check_bonus.block_tec": 15}, "desc": "Block against tech attacks: +15% chance."},
	"glass_mind": {"type": "keystone", "arm": "psi", "name": "Glass Mind", "at": Vector2(126, 1.03), "links": [],
		"mods": {"stat_pct.mag": 30, "stat_pct.hp": -25}, "desc": "TEC +30%.\nBUT max HP -25%."},

	# ------------------------------------------------ Shadow (Infiltrator) มุม 198
	"shadow_start": {"type": "start", "arm": "shadow", "job": "Infiltrator", "name": "Infiltrator", "at": Vector2(198, 0.40),
		"links": ["shadow_in", "shadow_l", "shadow_r"]},
	"shadow_in": {"type": "small", "arm": "shadow", "at": Vector2(198, 0.22), "links": ["hub"], "stats": {"spd": 2}},
	"shadow_l": {"type": "small", "arm": "shadow", "at": Vector2(187, 0.55), "links": ["light_step"], "stats": {"atk": 2}},
	"shadow_r": {"type": "small", "arm": "shadow", "at": Vector2(209, 0.55), "links": ["pickpocket"], "stats": {"lck": 3}},
	"light_step": {"type": "notable", "arm": "shadow", "name": "Light Step", "at": Vector2(183, 0.71), "links": ["shadow_out"],
		"mods": {"dodge_penalty": 0}, "desc": "Dodge loses its -20% penalty."},
	"pickpocket": {"type": "notable", "arm": "shadow", "name": "Pickpocket", "at": Vector2(213, 0.71), "links": ["shadow_out"],
		"mods": {"gold_bonus": 0.2}, "desc": "+20% credits from board tiles and monsters."},
	"shadow_out": {"type": "small", "arm": "shadow", "at": Vector2(198, 0.79), "links": ["second_chance"], "stats": {"spd": 2}},
	"second_chance": {"type": "notable", "arm": "shadow", "name": "Second Chance", "at": Vector2(198, 0.91), "links": ["all_or_nothing"],
		"mods": {"reroll_first_fail": 1}, "desc": "Once per battle, your first failed slot is re-rolled."},
	"all_or_nothing": {"type": "keystone", "arm": "shadow", "name": "All or Nothing", "at": Vector2(198, 1.03), "links": [],
		"mods": {"perfect_mult": 2.0, "imperfect_mult": 0.7}, "desc": "Perfect hits deal x2.\nBUT non-Perfect hits deal x0.7."},

	# ------------------------------------------------ สะพาน (ระหว่างแฉกที่ติดกัน)
	"point_blank": {"type": "bridge", "arm": "bridge", "name": "Point Blank", "at": Vector2(-54, 0.52), "links": ["assault_r", "precision_l"],
		"mods": {"counter_mult": 1.0}, "desc": "Counter strikes back with ATK x1.0 (was x0.8)."},
	"smart_rounds": {"type": "bridge", "arm": "bridge", "name": "Smart Rounds", "at": Vector2(18, 0.52), "links": ["precision_r", "machine_l"],
		"mods": {"attack_uses_avg_tec": true}, "desc": "Attack uses (ATK + TEC) / 2 if that is higher."},
	"neural_link": {"type": "bridge", "arm": "bridge", "name": "Neural Link", "at": Vector2(90, 0.52), "links": ["machine_r", "psi_l"],
		"mods": {"drone_check_bonus": 5}, "desc": "While your drone is active: +5% on all TEC checks."},
	"toxic_mind": {"type": "bridge", "arm": "bridge", "name": "Toxic Mind", "at": Vector2(162, 0.52), "links": ["psi_r", "shadow_l"],
		"mods": {"poison_bonus": 1}, "desc": "Your poison and burns deal +1 damage per turn."},
	"ambush": {"type": "bridge", "arm": "bridge", "name": "Ambush", "at": Vector2(234, 0.52), "links": ["shadow_r", "assault_l"],
		"mods": {"first_turn_attack_slots": 1}, "desc": "First turn of a battle: Attack gets +1 slot."},
}

static var _adj := {}


# ================================================================ ข้อมูลโหนด
static func neighbors(id: String) -> Array:
	if _adj.is_empty():
		for k in NODES:
			_adj[k] = []
		for k in NODES:
			for l in NODES[k].links:
				if not _adj[k].has(l):
					_adj[k].append(l)
				if _adj.has(l) and not _adj[l].has(k):
					_adj[l].append(k)
	return _adj.get(id, [])


## ตำแหน่งบนจอแบบหน่วย (-1.1..1.1) ศูนย์กลาง = (0, 0)
static func unit_pos(id: String) -> Vector2:
	var at: Vector2 = NODES[id].at
	return Vector2.from_angle(deg_to_rad(at.x)) * at.y


static func start_of(job: String) -> String:
	for k in NODES:
		if NODES[k].type == "start" and NODES[k].get("job", "") == job:
			return k
	return ""


static func title(id: String) -> String:
	var n: Dictionary = NODES[id]
	if n.has("name"):
		return n.name
	return stats_text(id)


## "+5 HP, +2 ATK"
static func stats_text(id: String) -> String:
	var parts := PackedStringArray()
	var st: Dictionary = NODES[id].get("stats", {})
	for k in GameData.STAT_KEYS:
		if st.get(k, 0) != 0:
			parts.append("%+d %s" % [st[k], GameData.stat_label(k)])
	return ", ".join(parts)


## คำอธิบายผลของโหนด (ค่าพลัง + ผลพิเศษ)
static func effect_text(id: String) -> String:
	var n: Dictionary = NODES[id]
	var lines := PackedStringArray()
	var st := stats_text(id)
	if st != "":
		lines.append(st)
	if n.has("desc"):
		lines.append(n.desc)
	if not is_active(id):
		lines.append("(Battle effect coming soon)")
	return "\n".join(lines)


## ผลพิเศษ (mods) ของโหนดนี้ทำงานแล้วหรือยัง
static func is_active(id: String) -> bool:
	for m in NODES[id].get("mods", {}):
		if not ACTIVE_MODS.has(m):
			return false
	return true


static func type_name(id: String) -> String:
	return {"start": "Start", "small": "Node", "notable": "Notable", "keystone": "KEYSTONE", "bridge": "Bridge Notable", "hub": "Core"}[NODES[id].type]


# ================================================================ กติกาการลงแต้ม
## โหนดที่ลงไว้ (ไม่รวมจุดเริ่ม) + จุดเริ่มของอาชีพ = ชุดที่ "มี" อยู่
static func owned(allocated: Array, job: String) -> Array:
	var out := allocated.duplicate()
	var s := start_of(job)
	if s != "" and not out.has(s):
		out.append(s)
	return out


## ลงแต้มที่โหนดนี้ได้ไหม (ไม่ได้เช็คจำนวนแต้ม)
static func can_allocate(allocated: Array, id: String, job: String) -> bool:
	if not NODES.has(id) or NODES[id].type == "start" or allocated.has(id):
		return false
	var have := owned(allocated, job)
	for nb in neighbors(id):
		if have.has(nb):
			return true
	return false


## ทุกโหนดใน allocated ยังเดินถึงจากจุดเริ่มไหม
static func is_connected_tree(allocated: Array, job: String) -> bool:
	var start := start_of(job)
	if start == "":
		return allocated.is_empty()
	var have := owned(allocated, job)
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for nb in neighbors(cur):
			if have.has(nb) and not seen.has(nb):
				seen[nb] = true
				stack.append(nb)
	for a in allocated:
		if not seen.has(a):
			return false
	return true


## เอาโหนดนี้ออกแล้วต้นยังไม่ขาดไหม
static func can_refund(allocated: Array, id: String, job: String) -> bool:
	if not allocated.has(id):
		return false
	var rest := allocated.duplicate()
	rest.erase(id)
	return is_connected_tree(rest, job)


## ค่าพลังรวมจากโหนดที่ลงไว้
static func stat_bonus(allocated: Array, key: String) -> int:
	var v := 0
	for id in allocated:
		v += int(NODES.get(id, {}).get("stats", {}).get(key, 0))
	return v


## รวม mods ของโหนดที่ลงไว้ (ตัวเลขบวกกัน, ค่าอื่นทับ) — ใช้ใน T-062
static func mods(allocated: Array) -> Dictionary:
	var out := {}
	for id in allocated:
		var m: Dictionary = NODES.get(id, {}).get("mods", {})
		for k in m:
			var v = m[k]
			if out.has(k) and (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and typeof(out[k]) == typeof(v):
				out[k] += v
			else:
				out[k] = v
	return out


# ================================================================ ตรวจข้อมูล (ใช้ใน test)
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var types := {}
	for k in NODES:
		var n: Dictionary = NODES[k]
		types[n.type] = types.get(n.type, 0) + 1
		for key in ["type", "arm", "at", "links"]:
			if not n.has(key):
				errors.append("%s: missing %s" % [k, key])
		for l in n.get("links", []):
			if not NODES.has(l):
				errors.append("%s links to unknown node %s" % [k, l])
		for s in n.get("stats", {}):
			if not GameData.STAT_KEYS.has(s):
				errors.append("%s: unknown stat %s" % [k, s])
		if n.type in ["notable", "keystone", "bridge"] and (not n.has("name") or not n.has("desc")):
			errors.append("%s: notable/keystone/bridge needs name + desc" % k)
	var want := {"start": 5, "small": 20, "notable": 15, "keystone": 5, "bridge": 5, "hub": 1}
	for t in want:
		if types.get(t, 0) != want[t]:
			errors.append("expected %d %s nodes, found %d" % [want[t], t, types.get(t, 0)])
	# ทุกอาชีพมีจุดเริ่ม และทุกโหนดเดินถึงจากทุกจุดเริ่ม (จุดเริ่มอาชีพอื่นเดินผ่านไม่ได้)
	for job in GameData.JOBS:
		var start := start_of(job)
		if start == "":
			errors.append("job %s has no start node" % job)
			continue
		var seen := {start: true}
		var stack := [start]
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			for nb in neighbors(cur):
				if seen.has(nb) or NODES[nb].type == "start":
					continue
				seen[nb] = true
				stack.append(nb)
		for k in NODES:
			if NODES[k].type != "start" and not seen.has(k):
				errors.append("%s can't reach %s" % [job, k])
		for id in GameData.JOBS[job].get("suggested", []):
			if not NODES.has(id):
				errors.append("%s suggested path has unknown node %s" % [job, id])
	return errors
