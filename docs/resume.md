<!-- SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee -->
<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# Resume: the evidence change (parked 2026-11-25)

The game is live at https://v-sekai-fire.github.io/interactor-swiss-family-saga/ and everything up to the Hint and Solve split is merged on `main`. This branch (`dev/evidence-not-hints`) holds one change that is not finished. The game is off the fabric beta (RFD66606-2360), so it waits until the owner says to resume.

## What the change does

The owner asked for enough data on the screen to solve a question without a hint ("treat it as frontier learning for the player"). The change removes the Hint button and the 💡 clue and puts an evidence block on the choice card: the family table (role, speed, free at), what the chapter still asks after this question, and the player's record by kind of question (`who goes`, `properly or quick`, `worth doing`) with the weakest kind named as the edge. `Solve` stays a toggle. `game/scripts/game_state.gd` has `evidence()` (facts only, no answer); `game/scripts/main.gd` has `_show_evidence`, `_record_line`; `game/tests/evidence.gd` replaces `clues.gd` and passes (36 questions).

## What is not finished

1. The choice card is about 130 px too tall: the layout check (below) breaks in 36 of 60 states. Shorten the block (members in either option only, or three lines of "after") or move the family table to the left card.
2. `game/tests/flow.gd` has two failing checks about the record line ("a right answer counts once in the record", "the record line shows it"). The record is counted in `_choose`; check the test's order of `_choose` and `Solve`.

## How to check, on any machine

- Official Godot 4.6 (no fork needed): `godot --headless --path . --script game/tests/NAME.gd` for `conformance`, `gameplay`, `choices`, `evidence` and `flow`. The four older suites pass; `conformance` is 1,304 of 1,304.
- Layout: `godot --headless --path . --script game/tests/layout.gd -- layout.json`, then `lean --run tools/layout_check.lean layout.json` (a Lean 4 toolchain; the check is not in CI). It must print `0 with a broken rule`.
- Browser: export with the Web preset and open it in Chromium (Playwright). The scripts used for this are not in the repository; the recipe is: serve `build/web`, load the page, wait about 18 s for the pack, click, take a screenshot.
- Levels are solved with MiniZinc through the Elixir tools (`tools/solve_level.exs`, `tools/conformance.exs`); they need `MINIZINC_HOME` and `FRONTIER_HOME`. The game itself needs neither.

## Rules for this repository

Comments at most 3% of code lines; REUSE headers (`reuse lint` must pass); commits authored as the owner with no agent credit and no trailing period; work lands on `dev/` branches and is merged to `main`; the page is deployed by the `pages` workflow when `main` changes.
