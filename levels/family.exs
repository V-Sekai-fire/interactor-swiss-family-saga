# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The family of Johann David Wyss's "Der schweizerische Robinson" (1812, public domain) as Party Saga characters, and the island as a graph.
# Names and roles are the story's: the father (support, knows a great deal), the mother Elizabeth (healer, the bag of supplies, the cook), Fritz (15, strongest: tank),
# Ernest (13, the marksman: damage), Jack (11, the quickest: damage who sprints), Francis (8, small, stays near the mother: support with a short reach).
defmodule Family do
  import Saga, only: [char: 1]
  @home 1
  def chars do
    [
      char(home: @home, role: :support, reach: 5, perform: true),                 # 1 the father
      char(home: @home, role: :healer, reach: 5, stride: 90),                     # 2 the mother
      char(home: @home, role: :tank, reach: 7, stride: 110, modes: ~w(STICK)),    # 3 Fritz
      char(home: @home, role: :damage, reach: 8, perform: true),                  # 4 Ernest
      char(home: @home, role: :damage, reach: 5, stride: 120, modes: ~w(STICK SPRINT)), # 5 Jack
      char(home: @home, role: :support, reach: 3, stride: 70)                     # 6 Francis
    ]
  end
  @names ["father", "mother", "Fritz", "Ernest", "Jack", "Francis"]
  def names, do: @names
end

defmodule Island do
  # The places, in the order of the nodes: Safety Bay, Tentholm, Falconhurst, Woodlands, Prospect Hill, Shark Island, Rockburg, Cape Minster.
  @places ["Safety Bay", "Tentholm", "Falconhurst", "Woodlands", "Prospect Hill", "Shark Island", "Rockburg", "Cape Minster"]
  def places, do: @places
  # Land paths, the river and the sea. Shark Island lies across water: swimming or the boat is the only way.
  # The model's edges are one-way, so every path is listed both ways.
  def edges do
    one_way = [{1, 2, 3, :land}, {2, 3, 4, :land}, {1, 3, 6, :water}, {3, 4, 5, :land}, {4, 5, 6, :land},
               {2, 6, 8, :water}, {3, 7, 4, :land}, {5, 8, 7, :land}]
    one_way ++ Enum.map(one_way, fn {a, b, length, terrain} -> {b, a, length, terrain} end)
  end
  # One zone per place; the number is how many arms may work there at once (a character works with one arm or both).
  def zones, do: [8, 8, 8, 8, 6, 6, 8, 6]
end
