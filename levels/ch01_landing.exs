# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Chapter 1, the landing: the wreck lies off Safety Bay; the family must bring the stores ashore, set up Tentholm and find fresh water before night.
# Places: 1 Safety Bay (the family lands here), 2 Tentholm (the first camp), 3 Falconhurst (the grove where the tree house is built later).
defmodule Ch01Landing do
  import Saga, only: [world: 1, task: 1]
  def world do
    world(
      nodes: 3,
      edges: Island.edges() |> Enum.filter(fn {a, b, _, _} -> a <= 3 and b <= 3 end),
      chars: Family.chars(),
      zones: Enum.take(Island.zones(), 3),
      tasks: [
        task(kind: :duty, at: 1, zone: 1, quick: 6, perf: 6, roles: {1, 0, 0, 1}, points: 5, name: "haul the stores from the wreck: the strong and a steady hand"),   # haul the stores from the wreck: the strong and a steady hand
        task(kind: :scout, at: 1, zone: 1, quick: 3, perf: 5, required: false, bonus: 6, points: 3, name: "round up the livestock and the dogs"),   # round up the livestock and the dogs
        task(kind: :duty, at: 2, zone: 2, quick: 8, perf: 8, roles: {1, 0, 1, 1}, points: 10, name: "raise the tent at Tentholm"),   # raise the tent at Tentholm
        task(kind: :scout, at: 3, zone: 3, quick: 4, perf: 7, bonus: 8, points: 6, name: "find fresh water at Falconhurst"),   # find fresh water at Falconhurst
        task(kind: :duty, at: 2, zone: 2, quick: 5, perf: 5, roles: {0, 1, 0, 0}, required: false, points: 4, name: "the mother lights the first fire and cooks")   # the mother lights the first fire and cooks
      ],
      pairs: [{1, 3}],   # the stores come ashore before the tent goes up
      tw: 1, pw: 2
    )
  end
end
