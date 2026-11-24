# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 3, the tub boat: the wreck still holds timber, tools and powder. Cut tubs in half, join them to a raft and cross to Shark Island and back
# before the weather turns. Jack is quickest on land, Fritz the strongest swimmer and builder, Ernest the shot who keeps watch for sharks.
defmodule Ch03Boat do
  import Saga, only: [world: 1, task: 1]
  def title, do: "The tub boat"
  def world do
    world(
      nodes: 6,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 6 and b <= 6 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 6),
      tasks: [
        task(kind: :duty, at: 1, zone: 1, quick: 9, perf: 9, roles: {1, 0, 1, 1}, points: 10),            # 1 cut and join the tubs into a boat
        task(kind: :duty, at: 1, zone: 1, quick: 6, perf: 6, roles: {1, 0, 0, 1}, points: 7),             # 2 carry planks and tools from the wreck
        task(kind: :scout, at: 6, zone: 6, quick: 5, perf: 8, bonus: 10, points: 8),                      # 3 cross to Shark Island and scout it
        task(kind: :duty, at: 6, zone: 6, quick: 7, perf: 7, roles: {1, 0, 2, 0}, points: 9),             # 4 drive off the sharks and gather salt
        task(kind: :scout, at: 5, zone: 5, quick: 4, perf: 6, required: false, bonus: 5, points: 4),      # 5 watch the sea from Prospect Hill
        task(kind: :duty, at: 3, zone: 3, quick: 5, perf: 5, roles: {0, 1, 0, 1}, required: false, points: 5) # 6 mother and a helper store the salt
      ],
      pairs: [{1, 3}, {2, 3}, {3, 4}],
      tw: 1, pw: 2
    )
  end
end
