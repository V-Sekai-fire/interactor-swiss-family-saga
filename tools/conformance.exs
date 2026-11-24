# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Conformance fixtures for the plan checker in the game: for each chapter take the optimal plan, perturb it and ask the Party Saga model itself whether the perturbed plan is
# allowed and what it scores. The checker in the game must give the same verdict and the same objective for every fixture (conformance/CHAPTER.json).
# Usage: elixir tools/conformance.exs CHAPTER [PERTURBATIONS] [SEED]
home = System.get_env("FRONTIER_HOME", "/mnt/fire/3-interactor/interactor-persona-frontier")
minizinc = System.get_env("MINIZINC_HOME", "/mnt/fire/6-datasource/minizinc-bundle/x/MiniZincIDE-2.11.0-x86_64-linux-gnu")
Code.require_file(Path.join(home, "tools/party_saga.exs"))
Code.require_file(Path.expand("../levels/family.exs", __DIR__))
[chapter | rest] = System.argv()
Code.require_file(Path.expand("../levels/#{chapter}.exs", __DIR__))
w = Module.concat([Macro.camelize(chapter)]).world()
variant = System.get_env("VARIANT", "")
w = if variant == "strict", do: %{w | tasks: Enum.map(w.tasks, &%{&1 | reach: 4})}, else: w
# tight: every zone holds exactly its largest single task, so two tasks of one zone at once are over capacity
tight_zone = fn z ->
  usage = for t <- w.tasks, t.zone == z, do: (if t.kind == :duty, do: 2 * (t.roles |> Tuple.to_list() |> Enum.sum()), else: 2)
  Enum.max([2 | usage])
end
w = if variant == "tight", do: %{w | zones: Enum.map(1..length(w.zones), tight_zone)}, else: w
count = String.to_integer(Enum.at(rest, 0, "30"))
:rand.seed(:exsss, {String.to_integer(Enum.at(rest, 1, "1")), 2, 3})
nc = length(w.chars)
nt = length(w.tasks)

list = fn out, name ->
  [_, body] = Regex.run(~r/#{name} = \[(.*?)\];/, out)
  body |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
end

optimum = Saga.solve_world(w, "chuffed", 30)
out = to_string(optimum.out)
base = %{
  done: list.(out, "done") |> Enum.map(&(&1 == "true")),
  party: list.(out, "party") |> Enum.map(&String.to_integer/1),
  how: list.(out, "how"),
  arm: list.(out, "arm"),
  start: list.(out, "start") |> Enum.map(&String.to_integer/1)
}

# the plan as the model's data file: fixing the decision variables leaves only the end time free, and the objective minimizes it
plan_dzn = fn p ->
  part = for c <- 1..nc, t <- 1..nt, do: if(Bitwise.band(Enum.at(p.party, t - 1), Bitwise.bsl(1, c - 1)) != 0, do: "true", else: "false")
  held = "[]"
  "done = [#{Enum.join(Enum.map(p.done, &to_string/1), ", ")}];\npart = array2d(1..#{nc}, 1..#{nt}, [#{Enum.join(part, ", ")}]);\n" <>
    "how = [#{Enum.join(p.how, ", ")}];\narm = [#{Enum.join(p.arm, ", ")}];\nstart = [#{Enum.join(Enum.map(p.start, &to_string/1), ", ")}];\nheld = #{held};\n"
end

verdict = fn p ->
  dir = Path.join(System.tmp_dir!(), "conf-#{System.unique_integer([:positive])}")
  File.mkdir_p!(dir)
  File.write!(Path.join(dir, "w.dzn"), Saga.render(w))
  File.write!(Path.join(dir, "p.dzn"), plan_dzn.(p))
  {out, _} = System.cmd(Path.join(minizinc, "bin/minizinc"), ["--solver", "chuffed", "-t", "20000", Saga.mzn(), Path.join(dir, "w.dzn"), Path.join(dir, "p.dzn")],
    env: [{"LD_LIBRARY_PATH", Path.join(minizinc, "lib")}], stderr_to_stdout: true)
  File.rm_rf!(dir)
  cond do
    String.contains?(out, "=====UNSATISFIABLE=====") -> %{feasible: false}
    match = Regex.run(~r/objective = (-?\d+);/, out) -> %{feasible: true, objective: String.to_integer(Enum.at(match, 1))}
    true -> %{feasible: :unknown}
  end
end

pick = fn xs -> Enum.at(xs, :rand.uniform(length(xs)) - 1) end
perturb = fn p ->
  t = :rand.uniform(nt) - 1
  case :rand.uniform(if variant == "", do: 6, else: 8) do
    1 -> %{p | start: List.replace_at(p.start, t, max(0, Enum.at(p.start, t) + pick.([-3, -1, 1, 2, 5])))}
    2 -> %{p | party: List.replace_at(p.party, t, Bitwise.bxor(Enum.at(p.party, t), Bitwise.bsl(1, :rand.uniform(nc) - 1)))}
    3 -> %{p | how: List.replace_at(p.how, t, pick.(["QUICK", "PERFORMANCE"]))}
    4 -> %{p | arm: List.replace_at(p.arm, t, pick.(["LEFT", "RIGHT", "BOTH"]))}
    5 -> %{p | done: List.replace_at(p.done, t, not Enum.at(p.done, t))}
    6 -> %{p | start: Enum.map(p.start, &(&1 + 1))}
    # a member is replaced by another character of the same role: the role mix holds, so only reach, travel and time can refuse it
    8 ->
      roles = Enum.map(w.chars, & &1.role)
      mask = Enum.at(p.party, t)
      members = for c <- 0..(nc - 1), Bitwise.band(mask, Bitwise.bsl(1, c)) != 0, do: c
      swaps = for c <- members, d <- 0..(nc - 1), d != c, Bitwise.band(mask, Bitwise.bsl(1, d)) == 0, Enum.at(roles, d) == Enum.at(roles, c), do: {c, d}
      if swaps == [], do: p, else: (fn {c, d} -> %{p | party: List.replace_at(p.party, t, Bitwise.bxor(mask, Bitwise.bor(Bitwise.bsl(1, c), Bitwise.bsl(1, d))))} end).(pick.(swaps))
    # two tasks of one zone start together: the zone's arms are counted
    _ ->
      zone_of = fn i -> Enum.at(w.tasks, i).zone end
      others = for u <- 0..(nt - 1), u != t, zone_of.(u) == zone_of.(t), do: u
      if others == [], do: p, else: %{p | start: List.replace_at(p.start, t, Enum.at(p.start, pick.(others)))}
  end
end

plans = [base | for(_ <- 1..count, do: base |> perturb.() |> then(fn p -> if :rand.uniform(3) == 1, do: perturb.(p), else: p end))]
cases = for p <- plans, do: Map.merge(%{plan: p}, verdict.(p))
known = Enum.reject(cases, &(&1.feasible == :unknown))
atom_free = fn
  v when is_atom(v) and v not in [true, false, nil] -> to_string(v)
  v -> v
end
terrain = fn {a, b, len, ter} -> [a, b, len, atom_free.(ter)] end
world = %{nodes: w.nodes, edges: Enum.map(w.edges, terrain), zones: w.zones, pairs: Enum.map(w.pairs, &Tuple.to_list/1), time_weight: w.tw, point_weight: w.pw,
          climb_min_reach: w.climb, blink_range: w.blink, crystals: Enum.map(w.crystals, atom_free),
          chars: Enum.map(w.chars, fn c -> %{home: c.home, modes: c.modes, reach: c.reach, stride: c.stride, perform: c.perform, role: atom_free.(c.role), slots: c.slots, cooldown: c.cooldown} end),
          tasks: Enum.map(w.tasks, fn t -> %{name: Map.get(t, :name, ""), kind: atom_free.(t.kind), at: t.at, zone: t.zone, required: t.required, quick: t.quick, perf: t.perf, reach: t.reach, roles: Tuple.to_list(t.roles),
                                             arts: Enum.map(t.arts, atom_free), points: t.points, min_points: t.minp, bonus: t.bonus, release: t.release, deadline: t.deadline} end)}
File.write!(Path.expand("../conformance/#{chapter}#{if variant == "", do: "", else: "_" <> variant}.json", __DIR__), JSON.encode!(%{chapter: chapter <> if(variant == "", do: "", else: " (" <> variant <> ")"), optimum: optimum.objective, world: world, cases: known}))
IO.puts("#{chapter}: optimum #{optimum.objective}; #{length(known)} cases, #{Enum.count(known, & &1.feasible)} allowed, #{Enum.count(known, &(not &1.feasible))} refused, #{length(cases) - length(known)} unknown")
