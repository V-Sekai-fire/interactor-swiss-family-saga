# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 8, the ship: years have passed. A sail is on the horizon. Light the fire on Prospect Hill, bring the journal to Safety Bay and receive the captain.
# Everyone is needed at the end; afterwards each of them chooses Europe or New Switzerland, which is a choice and not a task.
defmodule Ch08Ship do
  import Saga, only: [world: 1, task: 1]
  def title, do: "The ship"
  def world do
    world(
      nodes: 5,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 5 and b <= 5 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 5),
      tasks: [
        task(kind: :duty, at: 5, zone: 5, quick: 5, perf: 5, roles: {0, 0, 1, 1}, points: 8),             # 1 light the signal fire on Prospect Hill
        task(kind: :scout, at: 3, zone: 3, quick: 3, perf: 5, bonus: 8, points: 5),                       # 2 fetch the journal from Falconhurst
        task(kind: :duty, at: 1, zone: 1, quick: 8, perf: 8, roles: {1, 1, 1, 1}, points: 15),            # 3 receive the captain at Safety Bay: the whole party
        task(kind: :duty, at: 2, zone: 2, quick: 6, perf: 6, roles: {0, 1, 0, 1}, required: false, points: 6), # 4 the mother lays a table at Tentholm
        task(kind: :scout, at: 4, zone: 4, quick: 3, perf: 4, required: false, bonus: 4, points: 3)        # 5 a last walk through the fields
      ],
      pairs: [{1, 3}, {2, 3}],
      tw: 1, pw: 2
    )
  end
end
