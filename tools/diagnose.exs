# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Which task of a chapter cannot be done on its own? Each task is solved alone (the others are dropped); an unsatisfiable one is a fault in the level.
# Usage: elixir tools/diagnose.exs CHAPTER
home = System.fetch_env!("FRONTIER_HOME")
Code.require_file(Path.join(home, "tools/party_saga.exs"))
Code.require_file(Path.expand("../levels/family.exs", __DIR__))
[chapter] = System.argv()
Code.require_file(Path.expand("../levels/#{chapter}.exs", __DIR__))
w = Module.concat([Macro.camelize(chapter)]).world()
for {t, i} <- Enum.with_index(w.tasks, 1) do
  r = Saga.solve_world(%{w | tasks: [t], pairs: []}, "chuffed", 20)
  IO.puts("task #{i} (#{t.kind} at #{t.at}, roles #{inspect(t.roles)}, required #{t.required}): #{r.status}")
end
