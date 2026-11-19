# Brainrot Bazaar

[![make.fun](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/ahmadmulyadi1507/makefun-roblox-brainrot/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/ahmadmulyadi1507/makefun-roblox-brainrot/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

**Brainrot Bazaar** is a 3D steal-a-brainrot game for make.fun's
["Make the best AI Roblox brainrot game"](https://make.fun/bounty/roblox-brainrot-01)
bounty (roblox-brainrot-01). Built by an AI agent in recorded sessions.

## The game

Absurd meme-born characters ride a conveyor through a 3D bazaar, each
earning money every second. Buy them, stack them on your base, and climb
the ladder of rarities — while rivals (and Sneaky Steve, the NPC thief)
try to steal them from you, and a Noodle Tsunami sweeps the map every two
minutes.

- **The cast** — 12 original characters, Common to Secret: Sir Toastalot,
  Banana in a Suit, Turbo Gran, DJ Gherkin, Capybara CEO, Potato Astronaut,
  Waffle Wizard, Spaghetti Yeti, Chairman Meow, The Forbidden Fridge,
  Professor Bubblegum and Moonwalking Moose. Spawns can also roll Golden
  (x2), Diamond (x5) or Rainbow (x10) mutations.
- **The loop** — brainrots spawn on the conveyor, walk the belt, and despawn
  at the far end. Buy one before it leaves, and it earns on your base
  forever. Spend the cash on rarer brainrots, upgrades and rebirths.
- **The tension** — steal from unlocked bases and carry the prize home
  (carrying slows you down), slap thieves to make them drop it, lock your
  base for 30 seconds, and dash home when the tsunami warning sounds.
  Anyone caught outside their base is washed back to spawn.
- **Progression** — four upgrades (Speed Boots, Slap Power, Base Slots,
  Income Boost), each with 3 levels, and rebirths that trade everything for
  a permanent +50% income multiplier.

## How it is built

- `main.ts` (Node 22, standard library only) hands the game in: it copies
  `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output`,
  leaving out every name that starts with a dot, and writes
  `/output/dossier.json` with `vendor/makefun-roblox.ts`, the kit's copy,
  unchanged.
- `game.rbxl` is the place Rojo builds from `src/` and
  `default.project.json` (`rojo build default.project.json --output game.rbxl`).
- `src/shared/` holds the data both sides read: `BrainrotData` (the cast)
  and `Config` (every tuning number). `src/server/` holds the world builder,
  the character factory, the game service and the NPC rival; `src/client/`
  holds the HUD (shop, base panel, slap button, wave banner).
- `screenshots/` holds four pictures of the game; the first by name is the
  cover, and it is also the game's first thumbnail on Roblox.
- `PLAY.json` names the published place; `TOUR.json` is the optional tour
  for reviewers.

## Run it as the grader does

```sh
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the
kit's RULES.txt, which gives every command in order (Before you submit,
then Enter).
