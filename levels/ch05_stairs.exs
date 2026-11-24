# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 5, stairs and the bridge: the ladder is not safe for the mother and Francis. Cut a stair into the trunk of the great tree, bridge the creek to Woodlands
# and drive the boa from the path. The mother tends whoever is hurt.
defmodule Ch05Stairs do
  import Saga, only: [world: 1, task: 1]
  def title, do: "Stairs and the bridge"
  def world do
    world(
      nodes: 5,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 5 and b <= 5 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 5),
      tasks: [
        task(kind: :duty, at: 3, zone: 3, quick: 11, perf: 11, roles: {1, 0, 0, 1}, points: 11, name: "cut the stair into the trunk"),   # cut the stair into the trunk
        task(kind: :duty, at: 3, zone: 3, quick: 9, perf: 9, roles: {1, 0, 1, 1}, points: 10, name: "bridge the creek to Woodlands"),   # bridge the creek to Woodlands
        task(kind: :duty, at: 4, zone: 4, quick: 6, perf: 6, roles: {1, 0, 2, 0}, points: 9, name: "drive the boa from the path"),   # drive the boa from the path
        task(kind: :duty, at: 3, zone: 3, quick: 4, perf: 4, roles: {0, 1, 0, 0}, points: 5, name: "the mother tends the hurt"),   # the mother tends the hurt
        task(kind: :scout, at: 5, zone: 5, quick: 5, perf: 8, bonus: 9, points: 6, name: "scout the high path to Prospect Hill"),   # scout the high path to Prospect Hill
        task(kind: :scout, at: 4, zone: 4, quick: 3, perf: 5, required: false, bonus: 5, points: 4, name: "gather sago and fruit")   # gather sago and fruit
      ],
      pairs: [{1, 2}, {2, 3}],
      tw: 1, pw: 2
    )
  end
end
