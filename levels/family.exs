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
