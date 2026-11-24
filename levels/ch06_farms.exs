# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 6, farms and the pinnace: plant the fields at Woodlands, fence the animals, and rebuild the ship's pinnace on the shore so the family can sail round the island.
defmodule Ch06Farms do
  import Saga, only: [world: 1, task: 1]
  def title, do: "Farms and the pinnace"
  def world do
    world(
      nodes: 4,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 4 and b <= 4 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 4),
      tasks: [
        task(kind: :duty, at: 4, zone: 4, quick: 9, perf: 9, roles: {0, 1, 0, 1}, points: 9),             # 1 plant the fields (the mother and a helper)
        task(kind: :duty, at: 4, zone: 4, quick: 7, perf: 7, roles: {1, 0, 1, 0}, points: 7),             # 2 fence the livestock
        task(kind: :duty, at: 1, zone: 1, quick: 13, perf: 13, roles: {1, 0, 1, 1}, points: 14),          # 3 rebuild the pinnace at Safety Bay
        task(kind: :duty, at: 2, zone: 2, quick: 6, perf: 6, roles: {0, 0, 1, 1}, points: 6),             # 4 bring the pinnace's mast and sail to Tentholm
        task(kind: :scout, at: 3, zone: 3, quick: 4, perf: 6, required: false, bonus: 6, points: 4),      # 5 scout the grove for cotton and rope
        task(kind: :scout, at: 1, zone: 1, quick: 3, perf: 5, required: false, bonus: 4, points: 3)       # 6 test the pinnace in the bay
      ],
      pairs: [{3, 4}, {1, 3}],
      tw: 1, pw: 2
    )
  end
end
