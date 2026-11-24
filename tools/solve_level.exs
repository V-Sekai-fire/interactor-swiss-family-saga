# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Solve one chapter's world with the Party Saga model of interactor-persona-frontier and print what the solver proved.
# Usage: elixir tools/solve_level.exs CHAPTER [SOLVER] [LIMIT_S]   (the frontier checkout is found through FRONTIER_HOME)
home = System.get_env("FRONTIER_HOME", "/mnt/fire/3-interactor/interactor-persona-frontier")
Code.require_file(Path.join(home, "tools/party_saga.exs"))
Code.require_file(Path.expand("../levels/family.exs", __DIR__))
[chapter | rest] = System.argv()
Code.require_file(Path.expand("../levels/#{chapter}.exs", __DIR__))
module = Module.concat([Macro.camelize(chapter)])
solver = Enum.at(rest, 0, "chuffed")
limit = String.to_integer(Enum.at(rest, 1, "30"))
w = module.world()
r = Saga.solve_world(w, solver, limit)
IO.puts("#{chapter}: #{r.status}, objective #{inspect(r.objective)}, #{r.seconds} s with #{solver}")
IO.puts(r.out |> to_string() |> String.slice(0, 1500))
