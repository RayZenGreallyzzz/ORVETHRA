extends RefCounted
## Original ORVETHRA profession/JP rules (not claimed Rappelz values).
const STARTING_CLASSES := ["warrior", "mage", "rogue", "priest"]
const SPECIALIZATIONS := {
	"warrior": ["guardian", "berserker"],
	"mage": ["elementalist", "arcanist"],
	"rogue": ["ranger", "assassin"],
	"priest": ["healer", "oracle"]
}

static func new_job(base_class: String) -> Dictionary:
	if not STARTING_CLASSES.has(base_class):
		return {}
	return {"base_class": base_class, "advanced_class": "",
		"job_level": 1, "job_xp": 0, "jp": 0, "learned_skills": {}}

static func job_xp_to_next(level: int) -> int:
	return 50 + maxi(0, level - 1) * 30

static func grant_job_xp(job: Dictionary, amount: int) -> int:
	if amount <= 0 or job.is_empty():
		return 0
	job["job_xp"] = int(job["job_xp"]) + amount
	var levels := 0
	while int(job["job_level"]) < 100 and int(job["job_xp"]) >= job_xp_to_next(int(job["job_level"])):
		job["job_xp"] = int(job["job_xp"]) - job_xp_to_next(int(job["job_level"]))
		job["job_level"] = int(job["job_level"]) + 1
		job["jp"] = int(job["jp"]) + 1
		levels += 1
	return levels

static func specialize(job: Dictionary, specialization: String) -> bool:
	if job.is_empty() or not str(job.get("advanced_class", "")).is_empty() or int(job["job_level"]) < 20:
		return false
	var choices: Array = SPECIALIZATIONS.get(str(job["base_class"]), [])
	if not choices.has(specialization):
		return false
	job["advanced_class"] = specialization
	return true

static func learn(job: Dictionary, skill_id: String, cost: int, required_job_level: int) -> bool:
	if job.is_empty() or skill_id.is_empty() or cost < 1 or cost > 1000:
		return false
	if job["learned_skills"].has(skill_id) or int(job["job_level"]) < required_job_level or int(job["jp"]) < cost:
		return false
	job["jp"] = int(job["jp"]) - cost
	job["learned_skills"][skill_id] = true
	return true
