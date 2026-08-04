# Changelog

All notable changes to Dude Where's My K'arroc.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] — unreleased

A full overhaul. The addon used to be one campaign with two raw numbers, and a
mount you left behind stayed there forever. It is now a library of named game
types you choose from, and a retrieval service that brings your mount back.

### Added

- **Campaign library.** Eight campaigns you pick from a browsable list, gentlest
  first: Wayfarer, Pilgrim, Stablehand, Nomad, Ironhoof, Bonded, Caravan and
  Custom. Every card answers the same six questions in the same order — which
  mounts, what happens if you break it, leaving it, getting it back, picking it
  up, and anything else — so learning the format once makes every campaign
  readable at a glance. Cards expand in place, like reading an item.
- **Retrieval service.** Leave a mount behind and a goblin or gnome outfit goes
  and gets it. Two fixed timers: 60 seconds for them to reach your mount, then
  30 seconds to bring it to you if you're nearby or 3 minutes if you're not.
  Timer B is decided once, when they pick the mount up, and never recalculates.
  Worst case is four minutes.
- **Self-recovery.** Go back for a mount yourself and you get it instantly, from
  200 yards out — walking, riding or flying over the area at speed. The radius is
  deliberately loose; you shouldn't have to land on an exact coordinate.
- **The Ride key.** A key binding that only ever casts a mount your campaign
  allows. This is real prevention: an illegal mount is never cast, so there is no
  cast to interrupt and nothing to undo. Optional on-screen button too.
- **Pick-up radius drawn on the world map**, so a pin that clears while you're
  still short of the mount reads as arriving rather than as a bug. Backed by an
  approach message at 400 yards and a recovery message that always names its
  reason.
- **Retrieval tracker**, a small movable frame with the countdown and the two
  actions worth having to hand — send for it, and put a pin on it. Hides itself
  when nothing is happening.
- **Offline progress.** Both timers advance while you're logged out. Leave for an
  hour and your mount is waiting.
- **Housing neighborhoods are home ground.** No campaign rule applies inside one,
  whichever campaign you're running, and a mount you step off there is never
  treated as left behind. Neighborhoods are rested areas, so without this the
  settlement rule would have refused you a mount outside your own front door —
  and they're where mounts get shown off, which the addon has no business
  fighting. Detected via `C_Housing`, with every call guarded so a missing or
  moved function degrades quietly instead of erroring on every mount.
- `/dwmk sim` harness for testing retrieval timers without crossing a continent,
  and an offline test suite under `Tests/` covering 102 cases.

### Changed

- **Enforcement is now Off, Notify or Refuse — the grace period is gone.** Being
  handed a countdown and then pulled off a mount you already cast was the single
  most irritating thing the addon did. Either the mount is refused, or it isn't.
- **Rules are evaluated at cast time**, roughly 1.5 seconds before the mount
  appears, so a refused mount is removed the instant it shows rather than after a
  round of checks once you're already riding.
- Anchors and retrieval state are now **per character**. They were stored on the
  account-wide campaign, so two characters running the same campaign silently
  overwrote each other's mount locations.
- Rebuilt as fifteen namespaced modules instead of two files. No globals leak.
- Both dropdowns rebuilt on `DropdownButton` and `MenuUtil`; `UIDropDownMenu` was
  deprecated in 11.0 with no compatibility shim and `EasyMenu` was removed.
- Settings moved into the Blizzard settings panel, organised into six sections
  with a plain-language description under every control. Only the controls your
  active campaign actually uses are shown.

### Removed

- **TomTom dependency.** Waypoints now use the game's own map pin. Because the
  game allows exactly one pin — the same one you place yourself — the addon never
  takes it uninvited: you press Track it, your existing pin is saved, and it's put
  back when the mount comes home. Move the pin yourself and the addon lets go of
  it entirely.
- The `DWMK_CreateCampaign` global that bridged the old two files.

### Fixed

- `/dwmk status` printed a raw spell ID where a mount name belonged.
- The radius slider wrote unrounded floats and displayed `35.0000 yards`.
- The command handler was monkeypatched at load time, making behaviour depend on
  file order.

### Migration

Existing campaigns are carried over automatically and land on **Custom**, so
nothing about how they play changes. Old enforcement levels map as `Off → Off`,
`Permissive → Notify`, and both `Balanced` and `Strict → Refuse`. Version 1 saved
variables are left untouched as a rollback path and will be dropped in 2.1.

### Known limits

- An addon cannot stop the game summoning a mount; that has been closed to addons
  since 2006. The Ride key sidesteps it by never casting an illegal mount, and
  anything summoned another way is removed the moment it appears. The settings
  panel says so plainly rather than implying a hard block.
- "In a settlement" is approximated by the game's rested state, which covers
  cities and the inns at the heart of most towns. It errs permissive: you can ride
  the outskirts and are only stopped once properly inside.
- A dismount owed while you are airborne is held until you land. No campaign gets
  to kill you with fall damage.

## [1.0.0] — 2026-02-01

Initial release. Single campaign, four enforcement levels, TomTom waypoints.
