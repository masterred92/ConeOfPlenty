-- ConeOfPlenty: /reload with "Hide until I learn" already saved (FrostSuite r5). The saved choice is honoured on load, another
-- character's choice is not, and the box comes back by itself once the spell is learned.
package.path = "tests/?.lua;" .. package.path
local W = require("mock_wow"); W.install()
local check = W.check
W.level, W.known = 1, { [133] = true, [168] = true }
KennyConeOfPlentyDB = { hideUntilLearned = { ["Kenny-TestRealm"] = true, ["Alt-TestRealm"] = true } }   -- as saved before the reload
local ns = W.loadAddon(".", "ConeOfPlenty")
W.fire("PLAYER_LOGIN"); W.advance(2)
local FS = _G.FrostSuite_1_0
local row = FS.rows.ConeOfPlenty
local function know(ids, yes) for _, id in ipairs(ids) do W.known[id] = yes and true or nil end end

check(row.state == "hidden" and not (row.learnText and row.learnText.shown), "after /reload: still hidden, no learn line")
FS.Layout(); check(not row.shown, "takes no slot")
check(#ns.Core.errors == 0, "no Lua errors on load")
W.level = 35; know({ 120 }, true); W.talents = { [11180] = { 5, 5 } }
W.fire("SPELLS_CHANGED"); W.advance(2)
check(row.state ~= "learn" and row.state ~= "hidden" and KennyConeOfPlentyDB.hideUntilLearned["Kenny-TestRealm"] == nil, "learned: back by itself, this character's choice cleared")
check(KennyConeOfPlentyDB.hideUntilLearned["Alt-TestRealm"] == true, "another character's choice is kept")
W.level = 1; know({ 120 }, false); W.talents = nil
W.fire("SPELLS_CHANGED"); W.advance(2)
check(row.state == "learn" and row.learnText.shown and row.learnBtn.shown, "only another character hid it: this one shows the line")
W.done("ConeOfPlenty reload")
