# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 2, Falconhurst: the great tree at the river is the family's safe house. Fell the timber, raise a platform in the branches, bridge the river
# and bring the livestock over. Fritz climbs and fells, Ernest shoots game for the pot, the mother cooks, Francis keeps near her.
defmodule Ch02Falconhurst do
  import Saga, only: [world: 1, task: 1]
  def title, do: "Falconhurst"
  def world do
    world(
      nodes: 4,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 4 and b <= 4 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 4),
      tasks: [
        task(kind: :duty, at: 3, zone: 3, quick: 7, perf: 7, roles: {1, 0, 1, 0}, points: 6),            # 1 fell the timber at Falconhurst
        task(kind: :duty, at: 3, zone: 3, quick: 10, perf: 10, roles: {1, 0, 1, 1}, points: 12),          # 2 raise the platform in the branches
        task(kind: :duty, at: 2, zone: 2, quick: 8, perf: 8, roles: {1, 0, 0, 1}, points: 8),             # 3 build the bridge over the river
        task(kind: :scout, at: 4, zone: 4, quick: 4, perf: 6, bonus: 6, points: 4),                       # 4 scout Woodlands for sago palms
        task(kind: :scout, at: 1, zone: 1, quick: 3, perf: 4, required: false, bonus: 4, points: 3),      # 5 fetch the livestock from the bay
        task(kind: :duty, at: 2, zone: 2, quick: 5, perf: 5, roles: {0, 1, 0, 0}, required: false, points: 5) # 6 the mother cooks the evening meal
      ],
      pairs: [{1, 2}, {1, 3}],
      tw: 1, pw: 2
    )
  end
end
