# Changelog

## 1.0.1 (Nov 20, 2026)

- Layout fixes (FrostSuite-1.0 r4, shared by the suite): a status too long to sit beside the title moves to its own line instead of running into it, and box heights fit their text.
- Box is 64 px in combat, so a status moved off the title line fits.
- Low-level Mages (FrostSuite-1.0 r5, shared by the suite): until you have Cone of Cold and the Winter's Chill talent the box shows one calm line, e.g. `Learn Cone of Cold at level 26`, with a small **Hide until I learn** button (saved per character). It steps aside in combat and comes back by itself as soon as you learn them (checked when you learn a spell, level up, change talents or leave combat).

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
