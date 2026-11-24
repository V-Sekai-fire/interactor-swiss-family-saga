# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The gate for the plan checker: every fixture in conformance/ was made by the Party Saga model itself (tools/conformance.exs), so the checker must give the same
# verdict and, for an allowed plan, the same objective. Run: godot --headless --path . --script game/tests/conformance.gd
extends SceneTree

const CheckerScript := preload("res://game/scripts/checker.gd")

func _init() -> void:
	var failures := 0
	var total := 0
	var allowed := 0
	var dir := DirAccess.open("res://conformance")
	var names: Array = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			names.append(f)
	names.sort()
	for f in names:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://conformance/" + f))
		var world: Dictionary = data["world"]
		var bad := 0
		for c in data["cases"]:
			total += 1
			var verdict: Dictionary = CheckerScript.check(world, c["plan"])
			var ok := _agrees(c, verdict)
			if bool(c["feasible"]):
				allowed += 1
			if not ok:
				bad += 1
				if bad <= 3:
					print("DISAGREE %s: model says %s %s, checker says %s %s" % [f, c["feasible"], c.get("objective", ""), verdict["allowed"], verdict.get("objective", verdict.get("reason", ""))])
		failures += bad
		print("%s: %d cases, %d disagree" % [data["chapter"], data["cases"].size(), bad])
	# negative control: the comparison must notice a wrong answer, or "all agree" proves nothing
	var first = JSON.parse_string(FileAccess.get_file_as_string("res://conformance/" + names[0]))
	var control_case: Dictionary = first["cases"][0].duplicate(true)
	control_case["objective"] = int(control_case["objective"]) + 1
	var control_noticed := not _agrees(control_case, CheckerScript.check(first["world"], first["cases"][0]["plan"]))
	print("negative control noticed a wrong objective: %s" % control_noticed)
	print("RESULT: %d cases (%d allowed by the model), %d disagree" % [total, allowed, failures])
	quit(0 if failures == 0 and control_noticed and total > 0 else 1)

func _agrees(c: Dictionary, verdict: Dictionary) -> bool:
	if bool(c["feasible"]) != bool(verdict["allowed"]):
		return false
	return not bool(c["feasible"]) or int(c["objective"]) == int(verdict["objective"])
