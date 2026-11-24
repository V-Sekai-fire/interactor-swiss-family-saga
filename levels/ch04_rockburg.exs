# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 4, Rockburg: the rainy season is coming and the tree house will not hold. Hew a cave into the rock at Rockburg, fit it with stores, a hearth and a stable.
defmodule Ch04Rockburg do
  import Saga, only: [world: 1, task: 1]
  def title, do: "Rockburg"
  def world do
    world(
      nodes: 7,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 7 and b <= 7 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 7),
      tasks: [
        task(kind: :duty, at: 7, zone: 7, quick: 12, perf: 12, roles: {1, 0, 2, 1}, points: 14),          # 1 hew the great cave
        task(kind: :duty, at: 7, zone: 7, quick: 8, perf: 8, roles: {1, 0, 0, 1}, points: 8),             # 2 fit the walls and the floor
        task(kind: :duty, at: 3, zone: 3, quick: 6, perf: 6, roles: {0, 1, 0, 1}, points: 6),             # 3 pack the stores at Falconhurst
        task(kind: :scout, at: 5, zone: 5, quick: 5, perf: 8, bonus: 8, points: 6),                       # 4 scout Prospect Hill for clay and the best path
        task(kind: :scout, at: 4, zone: 4, quick: 3, perf: 5, required: false, bonus: 5, points: 4),      # 5 gather fruit in Woodlands
        task(kind: :duty, at: 7, zone: 7, quick: 5, perf: 5, roles: {0, 1, 0, 0}, required: false, points: 5) # 6 the mother builds the hearth
      ],
      pairs: [{1, 2}, {2, 3}],
      tw: 1, pw: 2
    )
  end
end
