# Changelog

## 1.0.0 (Nov 20, 2026)

First release, part of the Frost Suite.

- `SCOOP n/5` and `CONE NOW` for Winter's Chill, the Cone of Cold setup on Forever.
- Reads the real stacks when the game lets addons read Winter's Chill on your target. Otherwise, only at 5/5 talent, it
  counts your Frostbolts and Fingers-empowered Ice Lances (`counting casts`). Below 5/5 it says `CHANCE ONLY` and never
  shows a guessed count.
- A hidden stack count on a readable debuff stays unknown ("stack count hidden"), never a guessed 1.
- Idle strip in cast-counting mode reads `0/5 · counting casts`.
- Built-in readability test: `/frost cone debug` shows whether the debuff was readable out of combat and in combat.
- `/frost cone at 1-5 | sound on|off | debug`. Docks with the other Frost Suite boxes.
