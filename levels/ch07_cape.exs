# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 7, Cape Minster: with the pinnace the family can reach the far shore. Scout the cape, map the coast, raise a flag and a signal fire where ships can see it.
defmodule Ch07Cape do
  import Saga, only: [world: 1, task: 1]
  def title, do: "Cape Minster"
  def world do
    world(
      nodes: 8,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 8 and b <= 8 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 8),
      tasks: [
        task(kind: :scout, at: 8, zone: 8, quick: 6, perf: 10, bonus: 12, points: 9),                     # 1 scout Cape Minster
        task(kind: :duty, at: 8, zone: 8, quick: 9, perf: 9, roles: {1, 0, 1, 1}, points: 11),            # 2 raise the flag and the signal fire on the cape
        task(kind: :scout, at: 6, zone: 6, quick: 5, perf: 7, bonus: 7, points: 6),                       # 3 map Shark Island's far shore
        task(kind: :duty, at: 5, zone: 5, quick: 6, perf: 6, roles: {0, 0, 1, 1}, points: 7),             # 4 build the lookout cairn on Prospect Hill
        task(kind: :duty, at: 1, zone: 1, quick: 5, perf: 5, roles: {0, 1, 0, 1}, required: false, points: 5), # 5 provision the pinnace
        task(kind: :scout, at: 7, zone: 7, quick: 4, perf: 6, required: false, bonus: 5, points: 4)       # 6 check the cave stores at Rockburg
      ],
      pairs: [{5, 2}],
      tw: 1, pw: 2
    )
  end
end
