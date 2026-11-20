# Cone of Plenty

A tiny Frost Mage box for **WoW: Forever** (Interface 16001). Version 1.0.0. Part of Kenny's Frost Suite, and it works alone.

On Forever, Winter's Chill is a **Cone of Cold setup**, not a crit debuff. The talent's tooltip says Frostbolt and Fingers of
Frost empowered Ice Lance have a chance to apply Winter's Chill, "increasing the target's damage taken from your next Cone of
Cold by 20% and it gains an additional 7% of your spell damage, stacking up to 5 times." The chance per talent rank is
20/40/60/80/100%: that's the talent's effect-points curve in the game data for build 1.60.1.70862 (TraitDefinition 135293,
effect 1, Curve 83063), which fills the tooltip's chance. This box answers one question: dump Cone of Cold now, or keep stacking?

| Box says | Means |
| --- | --- |
| `SCOOP 3/5` | building |
| `CONE NOW` | 5 stacks (or your threshold: `/frost cone at 3`) |
| `CHANCE ONLY` | the game hides the stacks and your talent is below 5/5, so there's no honest count |

## Where the count comes from

| Mode | When | How |
| --- | --- | --- |
| stacks | the game lets addons read Winter's Chill on your target right now | the debuff's real stack count |
| `counting casts` | the stacks are hidden and Winter's Chill is 5/5 (100% apply) | your own Frostbolt casts, plus Ice Lance casts made while Fingers of Frost was visibly up (the buff, or the game's Ice Lance spell alert), on the current target, up to 5. It resets on Cone of Cold, a target change, or 15 seconds without a new stack (the debuff's length in the game's data). A miss can't be seen, so this is a count of casts, not a reading. |
| `CHANCE ONLY` | stacks hidden and the talent is below 5/5, or the rank can't be read | no stack number at all |
| `can't see your casts here` | stacks and your casts are both hidden | nothing to count |

## Readability test (result)

The build brief asked for a readability test before building this. Here's what can be said honestly:

- **Offline, from Blizzard's API docs (builds 70532 and 70862):** enemy auras are `SecretWhenUnitAuraRestricted` with
  `RequiresNonSecretAura`. In combat, an addon gets nothing for Winter's Chill on your target unless the game flags that spell
  as never secret. Whether 12579 has that flag isn't in the UI source or in the game data tables we have, so **it can't be
  settled offline**. Expect the in-combat answer to be "no" unless the game says otherwise.
- **In game:** the addon runs the test itself. Every time it looks at your target, it records whether Winter's Chill was
  readable, separately out of combat and in combat. `/frost cone debug` prints the result, for example
  `out of combat yes, in combat no`, plus the spell's secrecy flag. It then uses the best mode it's allowed, as in the table above.

## Commands

The Frost Suite has no per-addon slash commands, only `/frost <sub>`. That keeps the risk of clashing with other addons low.

- `/frost cone at 1-5`: when to say CONE NOW (default 5)
- `/frost cone sound on|off`: an optional quiet sound on CONE NOW (the game's chat-scroll click; off by default)
- `/frost cone debug`: the readability test result and what the game lets the addon see
- `/frost lock | unlock | scale 0.8-1.4 | reset | debug`: the shared dock

## Checks

`tests/run.sh <wow-ui-source>`, `tools/verify_unit_events.py <wow-ui-source>`, `tools/check_suite_lib.sh`, `tools/verify_media.sh`.
Spell IDs and durations come from the game's data tables (SpellName, SkillLineAbility, SpellEffect, SpellMisc, SpellDuration)
for build 1.60.1.70862.

MIT licence. Uses the game's own sounds and textures only.
