-- Cone of Plenty: a Winter's Chill counter for Frost Mages on WoW: Forever. Written from scratch (MIT).
--
-- Why: Winter's Chill on Forever is a Cone of Cold setup, not a crit debuff. Client tooltip (talent 11180): Frostbolt and
-- Fingers of Frost empowered Ice Lance have a 20/40/60/80/100% chance to apply Winter's Chill (debuff 12579), "increasing the
-- target's damage taken from your next Cone of Cold by 20% and it gains an additional 7% of your spell damage, stacking up to
-- 5 times." The question in the moment is "dump Cone of Cold now, or keep stacking?":
--   SCOOP 3/5   building           CONE NOW   at 5 (or your threshold)           CHANCE ONLY   can't know the stacks
--
-- How it knows the stacks (picked at runtime, never guessed; /frost cone debug prints it, and records whether the debuff on
-- your target was readable out of combat and in combat - the readability test the build brief asked for):
--   "aura":   Winter's Chill on your target can be read right now (never-secret, or the client says it isn't secret).
--             Its applications are the stacks.
--   "casts":  otherwise, only when the talent is 5/5 (100% apply): your own successful Frostbolt casts, and Ice Lance casts
--             made while Fingers of Frost was visibly up (buff read or the game's Ice Lance spell alert), on the current
--             target, capped at 5. Reset on Cone of Cold, target change, or 15 s without a new stack (the debuff's duration,
--             SpellMisc DurationIndex 8 = 15000 ms). Labelled "counting casts": a miss can't be seen.
--   "chance": talent below 5/5 (or its rank can't be read): CHANCE ONLY, no stack count at all.
--   "none":   the client hides your casts and the stacks: the box says so.
-- Spell IDs: SpellName + SkillLineAbility + SpellEffect (11180 triggers 12579), builds 1.60.1.70862 and 70888.
local ADDON, ns = ...
local C, Core, FS = ns.Compat, ns.Core, ns.FrostSuite
local L = Core.L

local CP = {}
KennyConeOfPlenty = CP
ns.CP = CP
local KEY = "ConeOfPlenty"
local SCHEMA = 1

CP.TALENT, CP.DEBUFF = 11180, 12579
CP.MAX, CP.DEBUFF_SECONDS = 5, 15
CP.CONE = { [120] = 1, [8492] = 2, [10159] = 3, [10160] = 4, [10161] = 5 }
CP.FROSTBOLT = { [116] = 1, [205] = 2, [837] = 3, [7322] = 4, [8406] = 5, [8407] = 6, [8408] = 7, [10179] = 8, [10180] = 9,
  [10181] = 10, [25304] = 11 }
CP.LANCE = { [1312002] = 1, [400640] = 2, [1240044] = 3, [1240045] = 4, [1240046] = 5, [1240047] = 6 }
CP.FINGERS = { 400669, 400670 }
CP.DEFAULTS = { threshold = 5 }

local db, settings, row
local migrations = {}
CP.count, CP.lastStack = 0, nil
CP.rank, CP.maxRank = nil, nil
CP.lit = {}
CP.hiddenEvents, CP.plainCasts = 0, 0
CP.known = true
CP.mode = "chance"
CP.state = "idle"
local gen = 0

local function now() return C.Clock() end
local function hasTarget() return not UnitExists or UnitExists("target") == true end

-- ---------- detection ----------
function CP.CastsHidden() return CP.hiddenEvents > 0 and CP.plainCasts == 0 end
-- Record the readability test result for the context we're in (only with a target to read).
function CP.RecordReadability(readable)
  if not (db and hasTarget()) then return end
  db.readable = db.readable or {}
  db.readable[C.InCombat() and "combat" or "outOfCombat"] = readable and true or false
end
function CP.EvaluateMode()
  local readable = FS.AuraReadableNow(CP.DEBUFF, "target")
  CP.RecordReadability(readable)
  if readable then CP.mode = "aura"
  elseif CP.rank and CP.maxRank and CP.rank >= CP.maxRank and CP.maxRank > 0 then
    CP.mode = CP.CastsHidden() and "none" or "casts"
  else CP.mode = "chance" end
  return CP.mode
end

function CP.ReadRank()
  if C.InCombat() then return end -- talents only re-read out of combat
  local r, m = FS.TalentRank(CP.TALENT)
  CP.rank, CP.maxRank = r, m
  if r == nil then CP.known = FS.IsMage() and FS.KnowsAny({ [CP.TALENT] = true }) ~= false
  else CP.known = FS.IsMage() and r > 0 end
end

function CP.FingersUp()
  for _, id in ipairs(CP.FINGERS) do
    local a, ok = FS.ReadAura("player", id)
    if ok and a then return true end
  end
  if C_SpellActivationOverlay then
    for id in pairs(CP.LANCE) do
      if CP.lit[id] or FS.Call(C_SpellActivationOverlay.IsSpellOverlayed, id) == true then return true end
    end
  end
  return false
end

-- Stacks now: a number, or nil when they can't be known.
function CP.Stacks()
  if CP.mode == "aura" then
    if not hasTarget() then return 0 end
    local a, ok = FS.ReadAura("target", CP.DEBUFF)
    if not ok then return nil end
    return a and math.min(CP.MAX, FS.AuraField(a, "applications") or 1) or 0
  elseif CP.mode == "casts" then
    if CP.lastStack and now() - CP.lastStack > CP.DEBUFF_SECONDS then CP.count, CP.lastStack = 0, nil end
    return CP.count
  end
  return nil
end

-- ---------- state ----------
local function schedule()
  gen = gen + 1
  local mine = gen
  C_Timer.After(1, function() if mine == gen then CP.Update() end end)
end

function CP.Update()
  CP.EvaluateMode()
  local n = CP.Stacks()
  local old = CP.state
  if not CP.known then CP.state = "hidden"
  elseif CP.mode == "none" then CP.state = "none"
  elseif n == nil then CP.state = "chance"
  elseif n >= (settings and settings.threshold or 5) then CP.state = "cone"
  elseif n > 0 then CP.state = "scoop"
  else CP.state = "idle" end
  CP.stacks = n
  if CP.state == "cone" and old ~= "cone" then
    if FS.RequestFlash(KEY, "PULSE") then FS.PlaySound(KEY) end
  end
  if row then CP.Paint() end
  if CP.mode == "casts" and CP.count > 0 then schedule() end
  return CP.state
end

function CP.Paint()
  local s, n = CP.state, CP.stacks
  if s == "hidden" then FS.State(KEY, "hidden"); return end
  FS.ClearLines(KEY)
  local tag = CP.mode == "casts" and L["counting casts"] or ""
  if s == "none" then
    FS.Headline(KEY, ""); FS.Bar(KEY, nil); FS.Status(KEY, L["can't see your casts here"], "Mist"); FS.State(KEY, "idle")
  elseif s == "chance" then
    FS.Headline(KEY, L["CHANCE ONLY"], "Mist"); FS.Bar(KEY, nil)
    FS.Status(KEY, CP.rank == nil and L["talent rank hidden"] or ("%d/%d"):format(CP.rank, CP.maxRank or 5), "Mist")
    FS.State(KEY, C.InCombat() and "active" or "idle")
  elseif s == "cone" then
    FS.Headline(KEY, L["CONE NOW"], "ScoopBlue"); FS.Bar(KEY, 1, "ScoopBlue"); FS.Status(KEY, tag, "Mist"); FS.State(KEY, "active")
  elseif s == "scoop" then
    FS.Headline(KEY, (L["SCOOP %d/%d"]):format(n, CP.MAX), "ScoopBlue"); FS.Bar(KEY, n / CP.MAX, "ScoopBlue")
    FS.Status(KEY, tag, "Mist"); FS.State(KEY, "active")
  else
    FS.Headline(KEY, ""); FS.Bar(KEY, nil)
    FS.Status(KEY, (C.InCombat() and tag ~= "") and tag or ("0/%d"):format(CP.MAX), "Mist")
    FS.State(KEY, C.InCombat() and "active" or "idle")
  end
end

-- ---------- events ----------
function CP.OnSpellcast(unit, _, spellID)
  if unit ~= "player" then return end
  if C.IsSecret(spellID) then
    CP.hiddenEvents = CP.hiddenEvents + 1
    return CP.Update()
  end
  if CP.CONE[spellID] then
    CP.plainCasts = CP.plainCasts + 1
    CP.count, CP.lastStack = 0, nil
  elseif CP.FROSTBOLT[spellID] or CP.LANCE[spellID] then
    CP.plainCasts = CP.plainCasts + 1
    -- Ice Lance only counts when Fingers of Frost was visibly up as it was cast (FoF-empowered)
    if CP.mode == "casts" and hasTarget() and (CP.FROSTBOLT[spellID] or CP.FingersUp()) then
      CP.count, CP.lastStack = math.min(CP.MAX, CP.count + 1), now()
    end
    if CP.LANCE[spellID] then CP.lit[spellID] = nil end
  else
    return
  end
  CP.Update()
end

function CP.OnTargetChanged() CP.count, CP.lastStack = 0, nil; CP.Update() end

function CP.OnGlow(show, spellID)
  if C.IsSecret(spellID) or not CP.LANCE[spellID] then return end
  CP.lit[spellID] = show or nil
end

local function yn(v) if v == nil then return "not checked yet" end return v and "yes" or "no" end
function CP.DetectionLines()
  CP.EvaluateMode()
  local r = db and db.readable or {}
  return {
    ("stacks: %s  (aura = Winter's Chill on your target read, casts = counting your casts at 5/5, chance = CHANCE ONLY, none = hidden)"):format(CP.mode),
    ("readability test, Winter's Chill (%d) on your target: out of combat %s, in combat %s"):format(CP.DEBUFF, yn(r.outOfCombat), yn(r.combat)),
    ("  aura secrecy %s (0 = never secret), readable right now: %s, target: %s"):format(tostring(FS.AuraSecrecy(CP.DEBUFF)),
      tostring(FS.AuraReadableNow(CP.DEBUFF, "target")), tostring(hasTarget())),
    ("Winter's Chill talent: %s/%s%s"):format(tostring(CP.rank), tostring(CP.maxRank), CP.rank == nil and " (rank can't be read: CHANCE ONLY)" or ""),
    ("stacks now: %s, counted: %d, threshold: %d, state: %s"):format(tostring(CP.stacks), CP.count, settings and settings.threshold or 5, CP.state),
    ("cast events: %d plain, %d hidden; secret restrictions: %s, in combat: %s"):format(CP.plainCasts, CP.hiddenEvents,
      tostring(FS.Restricted()), tostring(C.InCombat())),
  }
end

function CP.Slash(msg)
  local cmd, a = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "at" and tonumber(a) and tonumber(a) >= 1 and tonumber(a) <= 5 then
    settings.threshold = math.floor(tonumber(a)); Core.Print(L["CONE NOW at"] .. " " .. settings.threshold); CP.Update()
  elseif cmd == "sound" and (a == "on" or a == "off") then db.sound = a == "on"; Core.Print(L["sound:"] .. " " .. a)
  elseif cmd == "debug" then for _, l in ipairs(CP.DetectionLines()) do Core.Print(l) end
  else Core.Print("/frost cone at 1-5 | sound on|off | debug") end
end

-- ---------- wiring ----------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
for _, e in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "PLAYER_TARGET_CHANGED", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" }) do ev:RegisterEvent(e) end
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
ev:RegisterUnitEvent("UNIT_AURA", "target")

local function refresh() CP.ReadRank(); CP.Update() end
local handlers = {
  PLAYER_LOGIN = refresh, SPELLS_CHANGED = refresh, TRAIT_CONFIG_UPDATED = refresh, PLAYER_REGEN_ENABLED = refresh,
  PLAYER_REGEN_DISABLED = function() CP.Update() end,
  PLAYER_TARGET_CHANGED = CP.OnTargetChanged,
  UNIT_AURA = function(unit) if unit == "target" then CP.Update() end end,
  UNIT_SPELLCAST_SUCCEEDED = CP.OnSpellcast,
  SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(id) CP.OnGlow(true, id) end,
  SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(id) CP.OnGlow(false, id) end,
}
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    db = Core.Migrate(KennyConeOfPlentyDB, migrations, SCHEMA)
    KennyConeOfPlentyDB = db
    settings = Core.Settings(db.settings, CP.DEFAULTS)
    row = FS.Register(KEY, db, { title = L["Cone of Plenty"], slash = CP.Slash, help = "at 1-5 | sound on|off | debug", debug = Core.PrintDebug })
    Core.SafeCall("refresh", refresh)
    return
  end
  local h = handlers[event]
  if h and db then Core.SafeCall(event, h, ...) end
end)

Core.Setup({ cmd = "/frost cone",
  required = { "C_Timer.After" },
  optional = { "C_UnitAuras.GetUnitAuraBySpellID", "C_Secrets.HasSecretRestrictions", "C_Secrets.GetSpellAuraSecrecy",
    "C_Secrets.ShouldSpellAuraBeSecret", "C_ClassTalents.GetActiveConfigID", "C_Traits.GetTreeNodes", "C_Traits.GetNodeInfo",
    "C_Traits.GetEntryInfo", "C_Traits.GetDefinitionInfo", "C_SpellActivationOverlay.IsSpellOverlayed", "C_SpellBook.IsSpellKnown" },
  db = function() return db end,
  firstRun = { L["Cone of Plenty is ready: it counts Winter's Chill for Cone of Cold when the game lets it, and says CHANCE ONLY when it can't."] },
  debugLines = function() return CP.DetectionLines() end })
