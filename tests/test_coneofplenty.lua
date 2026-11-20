-- Cone of Plenty: aura stacks when readable, cast counting only at 5/5, CHANCE ONLY otherwise; never a guessed stack.
package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local S = W.S
local check = W.check
local ns = W.loadAddon(".", "ConeOfPlenty")
W.fire("PLAYER_LOGIN")
local CP, FS = ns.CP, _G.FrostSuite_1_0
local row = FS.rows.ConeOfPlenty
local WC, FB, LANCE, CONE, FOF = 12579, 25304, 400640, 10161, 400669

local function reset(rank)
  W.combat = false; W.target = "mob"; W.fire("PLAYER_REGEN_ENABLED"); W.advance(30)
  S.install(W); W.prints = {}; W.sounds = {}
  W.talents = rank and { [11180] = { rank, 5 } } or nil
  CP.count, CP.lastStack, CP.hiddenEvents, CP.plainCasts, CP.lit = 0, nil, 0, 0, {}
  FS.lastSound = -100; FS.flashKey = nil
  KennyConeOfPlentyDB.readable = nil
  W.fire("TRAIT_CONFIG_UPDATED")
end
local function fight() W.combat = true; W.fire("PLAYER_REGEN_DISABLED") end

-- 1. Strict client, talent 5/5: the stacks are secret in combat, so it counts casts and says so.
reset(5); fight()
check(CP.mode == "casts" and row.statusText == "counting casts", "5/5 + secret stacks: counting casts")
S.cast(FB); S.cast(FB)
check(CP.stacks == 2 and row.headText == "SCOOP 2/5", "two Frostbolts: SCOOP 2/5")
S.cast(LANCE)
check(CP.stacks == 2, "Ice Lance without visible Fingers: not counted")
S.gain(FOF, 1, 15) -- secret in combat: invisible
S.cast(LANCE)
check(CP.stacks == 2, "Fingers hidden (secret buff): Lance still not counted")
S.glow(LANCE, true); S.cast(LANCE)
check(CP.stacks == 3, "Fingers visible through the game's alert: Lance counted")
S.cast(FB); S.cast(FB)
check(CP.state == "cone" and row.headText == "CONE NOW" and FS.Glowing() == "ConeOfPlenty", "five: CONE NOW + pulse")
check(#W.sounds == 0, "Cone sound off by default")
S.cast(FB)
check(CP.stacks == 5, "capped at 5")
S.cast(CONE)
check(CP.stacks == 0 and CP.state == "idle", "Cone of Cold empties it")
S.cast(FB); W.fire("PLAYER_TARGET_CHANGED")
check(CP.stacks == 0, "target change resets")
S.cast(FB); W.advance(16)
check(CP.stacks == 0, "15 s without a stack: the debuff would be gone, count resets")
-- the readability test records what it saw
check(KennyConeOfPlentyDB.readable.combat == false and KennyConeOfPlentyDB.readable.outOfCombat == true, "readability recorded: out of combat yes, in combat no")
local dbg = table.concat(CP.DetectionLines(), "\n")
check(dbg:find("out of combat yes, in combat no", 1, true), "debug prints the readability test")

-- 2. Talent below 5/5 and secret stacks: CHANCE ONLY, no number ever.
reset(3); fight()
check(CP.mode == "chance" and row.headText == "CHANCE ONLY" and row.statusText == "3/5", "3/5: CHANCE ONLY")
S.cast(FB); S.cast(FB)
check(CP.stacks == nil and row.headText == "CHANCE ONLY", "casts don't create a fake stack count")
-- Talent rank unreadable: CHANCE ONLY with that reason.
reset(nil); fight()
check(CP.mode == "chance" and row.statusText == "talent rank hidden", "rank unknown: CHANCE ONLY")

-- 3. Never-secret Winter's Chill: real stacks in combat, any talent rank.
reset(2); S.never[WC] = true; fight()
check(CP.mode == "aura", "never-secret debuff: aura mode")
S.unitGain("target", WC, 3, 15)
check(CP.stacks == 3 and row.headText == "SCOOP 3/5" and row.statusText == "", "real stacks from the target")
S.unitGain("target", WC, 5, 15)
check(CP.state == "cone", "5 stacks: CONE NOW")
S.unitDrop("target", WC)
check(CP.stacks == 0, "debuff gone: 0")
-- threshold
SlashCmdList.FROSTSUITE("cone at 3")
S.unitGain("target", WC, 3, 15)
check(CP.state == "cone", "/frost cone at 3")
SlashCmdList.FROSTSUITE("cone at 5")
-- applications: secret = unknown (never a guessed 1); 0 = one application on a non-stacked aura.
local sv = {}; W.secret[sv] = true
S.unitGain("target", WC, 2, 15); S.unit.target[WC].applications = sv; W.fire("UNIT_AURA", "target", {})
check(CP.stacks == nil and CP.state == "chance" and row.statusText == "stack count hidden", "secret applications: count unknown, not 1")
S.unit.target[WC].applications = nil; W.fire("UNIT_AURA", "target", {})
check(CP.stacks == nil, "missing applications: unknown")
S.unit.target[WC].applications = 0; W.fire("UNIT_AURA", "target", {})
check(CP.stacks == 1 and row.headText == "SCOOP 1/5", "applications 0 on a present debuff: 1")
S.unitDrop("target", WC)

-- 3b. Idle out of combat in casts mode (debuff always secret, 5/5): the strip still says it is counting casts.
reset(5); S.always[WC] = true; CP.Update()
check(CP.mode == "casts" and CP.state == "idle" and row.statusText == "0/5 · counting casts", "idle out of combat: 0/5 · counting casts")
SlashCmdList.FROSTSUITE("cone at 5")

-- 4. Hidden casts at 5/5 with secret stacks: says it can't see.
reset(5); S.castSecretInCombat = true; fight()
S.cast(FB)
check(CP.mode == "none" and row.statusText == "can't see your casts here", "hidden casts: none")
-- 5. No talent: no slot.
reset(0)
check(row.state == "hidden", "Winter's Chill 0/5: hidden")
reset(5)
check(row.state ~= "hidden", "talented: shown")
local src = io.open("ConeOfPlenty.lua"):read("*a")
check(not src:find("CastSpell") and not src:find("TargetUnit") and not src:find("UseAction"), "no cast, target or movement calls")
W.done("ConeOfPlenty")
