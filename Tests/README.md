# Offline test harness

WoW addons can't be tested headlessly, so `harness.lua` stubs enough of the game
API to load and run DWMK's modules outside the client. It covers the parts that
are pure logic — migration, rule evaluation, the retrieval state machine, timer
arithmetic and preset rendering — which is most of the places a regression can
actually hide.

```sh
lua Tests/harness.lua .
```

Exits non-zero on any failure, so it drops straight into CI if you want it there.

## What it covers

| Section | What it proves |
|---|---|
| 1  | v1 → v2 migration, including the grace tier collapsing to Refuse |
| 2  | All 8 presets produce 6 rows and at least one chip, with no unsubstituted `{tokens}` |
| 3  | Card copy matches the constants in `Core/Init.lua` — the numbers a player reads are the numbers that run |
| 4  | Mount classification, including unknown type IDs erring toward flight-capable |
| 5  | Full retrieval cycle: leave → dispatch → Timer A → Timer B → delivered |
| 6  | Far tier, both by distance and by being on a different map |
| 7  | Self-recovery, the approach message, and cancelling a dispatched service |
| 8  | Offline time resolving both timers on login |
| 9  | Nomad refusing flyers and skyriding |
| 10 | Bonded refusing every mount but the named one |
| 11 | Caravan never dispatching |
| 12 | Enforcement Off permitting everything |
| 13 | Config, picker and tracker rendering under every preset |
| 14 | Tracker across every retrieval state, via Ironhoof's manual call |
| 15 | Every `/dwmk sim` subcommand |
| 16 | Settlements vs housing neighborhoods, including every rule standing down at home, nothing being stranded there, and `C_Housing` being absent or empty |

## What it can't cover

Anything that needs the real client: secure button behaviour and combat
lockdown, whether `Dismount()` actually fires, taint, the map circle's on-screen
geometry, and how any of it looks. Those are the in-game checklist in the
project plan, not this.

## Notes

Written against Lua 5.5 (via `scoop install lua`) while the game runs 5.1. That
gap is mostly a feature here: 5.5 raises an error on `string.format("%d", 3.7)`
where 5.1 silently truncates, which is how three float-formatting bugs were
caught that would otherwise have shipped looking fine.
