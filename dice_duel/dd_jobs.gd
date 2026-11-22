class_name DDJobs
## อาชีพ + สกิล (อาชีพละ 1 สกิล) — ตัวเลขอยู่ใน DDBalance

const IDS := ["warrior", "magician", "thief", "ninja", "cleric"]

const NAMES := {"warrior": "Warrior", "magician": "Magician", "thief": "Thief", "ninja": "Ninja", "cleric": "Cleric"}

const SKILLS := {
	"warrior": "Berserk",
	"magician": "Arcane Flow",
	"thief": "Swipe",
	"ninja": "Shadow Read",
	"cleric": "Sanctuary",
}

const SKILL_DESC := {
	"warrior": "Special attack: 3 dice of equal value, power x3 (counts as Strike). Free reroll of a 1 once per round.",
	"magician": "Magic can take extra dice. Each odd extra die adds +15% power.",
	"thief": "Once per battle, after the reveal, pay %d Focus: swap one of your placed dice with one of theirs." % DDBalance.SWIPE_FOCUS_COST,
	"ninja": "Once per round while placing: peek at one random secret die of the opponent.",
	"cleric": "When you Guard, heal sum x 2 HP.",
}
