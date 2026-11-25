# Playing and checking the game

Run it with a Godot 4 build: `godot --path . --resolution 1180x780`. Each of the eight chapters is a run of two-option decisions; every question has a clue on its card, and
**Edit by hand** opens the free board (any plan may be built, the checker names the first rule it breaks). The score is what the tasks add minus the time taken; the best plan
of each chapter was proved optimal by a MiniZinc solver, and the game shows where a plan loses points against it.

## How it is checked

- `game/tests/conformance.gd`: the plan checker (`game/scripts/checker.gd`, a port of the rules of the Party Saga model) must give the same verdict and objective as the model on every case in
  `conformance/`. Four deliberate breakages of the checker are each caught by these cases.
- `game/tests/gameplay.gd`, `game/tests/choices.gd`, `game/tests/clues.gd`: the rules of play, the two-option decisions (the best answers reach the best plan; every wrong answer costs at least five points)
  and the clues.
- Run any of them with `godot --headless --path . --script game/tests/NAME.gd`.

## Making the levels

`levels/*.exs` write each chapter as a Party Saga world. `tools/solve_level.exs CHAPTER` solves one with MiniZinc and `tools/conformance.exs CHAPTER` makes its fixtures. They need `FRONTIER_HOME`
(a checkout of `interactor-persona-frontier`, which holds `tools/party_saga.exs` and the model) and `MINIZINC_HOME` (an unpacked MiniZinc 2.11).
