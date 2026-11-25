# Playing and checking the game

Play it in the browser at https://v-sekai-fire.github.io/interactor-swiss-family-saga/ (built by the `pages` workflow on every push to `main`), or run it with a Godot 4.6 build: `godot --path . --resolution 1180x780`. Each of the eight chapters is a run of two-option decisions; every question has a clue on its card, and
**Edit by hand** opens the free board (any plan may be built, the checker names the first rule it breaks). The score is what the tasks add minus the time taken; the best plan
of each chapter was proved optimal by a MiniZinc solver, and the game shows where a plan loses points against it.

## How it is checked

- `game/tests/conformance.gd`: the plan checker (`game/scripts/checker.gd`, a port of the rules of the Party Saga model) must give the same verdict and objective as the model on every case in
  `conformance/`. Four deliberate breakages of the checker are each caught by these cases.
- `game/tests/gameplay.gd`, `game/tests/choices.gd`, `game/tests/clues.gd`: the rules of play, the two-option decisions (the best answers reach the best plan; every wrong answer costs at least five points)
  and the clues.
- `game/tests/flow.gd`: Next stays locked until the chapter is done, the tasks are listed with the required ones first, and the console speaks.
- `game/tests/layout.gd` and `tools/layout_check.lean`: the layout of every control in every state a player can reach (each chapter at each decision, the end screen and the free board) is dumped as JSON,
  and the Lean program checks that nothing leaves the window or its box, no text is cut off or hidden, and no two controls in one container overlap. Run
  `godot --headless --path . --script game/tests/layout.gd -- layout.json` and then `lean --run tools/layout_check.lean layout.json`.
- Run any of the Godot tests with `godot --headless --path . --script game/tests/NAME.gd`.

## Making the levels

`levels/*.exs` write each chapter as a Party Saga world. `tools/solve_level.exs CHAPTER` solves one with MiniZinc and `tools/conformance.exs CHAPTER` makes its fixtures. They need `FRONTIER_HOME`
(a checkout of `interactor-persona-frontier`, which holds `tools/party_saga.exs` and the model) and `MINIZINC_HOME` (an unpacked MiniZinc 2.11).
