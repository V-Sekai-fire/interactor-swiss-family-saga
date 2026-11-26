# How the code is laid out

Code comments stay under 3% of non-blank lines. The reasons live here.

## The screen (`game/scripts/main.gd`)

The game screen uses the Chibifire design system. It shows the chapter and its island, the tasks the chapter asks for, the family, and the plan the player builds. Any plan may be built. The checker judges it as it changes, and the score is set against the model's best plan.

- The left column holds the island and the plan as a timeline. The right column holds the tasks and the one being planned.
- The four state colours of the design system stand for the four roles.
- A toggle is outlined when off and inked when on. A task row is bare unless it is the one being planned, which is ringed.
- The chapters are a line, not a ring: nothing comes before the first or after the last.
- The console keeps the last few lines, newest at the bottom. Its row count assumes a wrap at about 50 characters, which is a little pessimistic.
- Earned stars show as emoji, with an empty circle for each star not yet earned.
- When two answers differ in one family member, the answer text describes that member.

### Role emoji

Each role has one emoji: 💪 tank, 🩹 healer, 🎯 damage, 🤝 support. It is shown after every name and in what a task needs, so the player matches people to a task by reading, not by remembering. The emoji belongs to the role, not the person, because a task asks for "a damage" and Ernest or Jack can fill it. A person's speed, reach and whether they can perform stay for the player to find out.

`FAMILY_ROLE` copies the roles in `levels/family.exs`. `game/tests/choices.gd` checks that every chapter agrees with it.

### The end of a chapter

When every decision is made, the screen works the score out: what the tasks earn, minus the days the plan takes. When the best plan scores more, its own sum is shown too. Then come the score the next star needs and where the points went. The next-star score uses the same ratio test as `stars()`, so float rounding cannot ask for one point too many.

### Dark mode

The design system has two schemes: "paper-and-ink" (light) and "observatory" (dark: night, brass and chalk). The first start follows the system setting (`DisplayServer.is_dark_mode()`, which is `prefers-color-scheme` in a browser). The Dark or Light button switches the scheme and reloads the screen, because the design system sets colours when the screen is built. The chapter is kept across the reload, but the answers already given in it start over. The choice is kept in static variables, so it lasts until the page is closed. In the dark scheme the duty mark in the task list is ⬜, because ⬛ cannot be seen on the night background.

The task list shows plain names, without role emoji, because "Father 🤝, Fritz 💪" does not fit its column.

## The timeline (`game/scripts/timeline.gd`)

One row per family member and one bar per task they are on, laid out in time. Duties are inked and scouting is the accent colour. The selected task has a ring, and the task the checker refuses is outlined in the design system's "bad" colour.

## The choices test (`game/tests/choices.gd`)

It plays every chapter as a run of two-option decisions. Always taking the best option reaches the best plan. Always taking the other option still gives a plan that works and scores less. Every step offers exactly two options.

Run: `godot --headless --path . --script game/tests/choices.gd`
