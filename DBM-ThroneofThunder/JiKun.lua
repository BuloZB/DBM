local mod	= DBM:NewMod(828, "DBM-ThroneofThunder", nil, 362)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 10140 $"):sub(12, -3))
mod:SetCreatureID(69712)
mod:SetZone()

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"UNIT_SPELLCAST_CHANNEL_START boss1",
	"UNIT_SPELLCAST_START boss1",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_AURA_REMOVED",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"CHAT_MSG_MONSTER_EMOTE"
)

local warnCaws				= mod:NewSpellAnnounce(138923, 2)
local warnQuills			= mod:NewCountAnnounce(134380, 4)
local warnFlock				= mod:NewAnnounce("warnFlock", 3, 15746)--Some random egg icon
local warnTalonRake			= mod:NewStackAnnounce(134366, 3, nil, mod:IsTank() or mod:IsHealer())
local warnDowndraft			= mod:NewSpellAnnounce(134370, 3)
local warnFeedYoung			= mod:NewSpellAnnounce(137528, 3)--No Cd because it variable based on triggering from eggs, it's cast when one of young call out and this varies too much
local warnPrimalNutriment	= mod:NewCountAnnounce(140741, 1)

local specWarnQuills		= mod:NewSpecialWarningSpell(134380, nil, nil, nil, 2)
local specWarnFlock			= mod:NewSpecialWarning("specWarnFlock", false)--For those assigned in egg/bird killing group to enable on their own (and tank on heroic)
local specWarnTalonRake		= mod:NewSpecialWarningStack(134366, mod:IsTank(), 2)--Might change to 2 if blizz fixes timing issues with it
local specWarnTalonRakeOther= mod:NewSpecialWarningTarget(134366, mod:IsTank())
local specWarnDowndraft		= mod:NewSpecialWarningSpell(134370, nil, nil, nil, 2)
local specWarnFeedYoung		= mod:NewSpecialWarningSpell(137528)
local specWarnBigBird		= mod:NewSpecialWarning("specWarnBigBird", mod:IsTank())
local specWarnBigBirdSoon	= mod:NewSpecialWarning("specWarnBigBirdSoon", false)
local specWarnFeedPool		= mod:NewSpecialWarningMove(138319, false)

--local timerCawsCD			= mod:NewCDTimer(15, 138923)--Variable beyond usefulness. anywhere from 18 second cd and 50.
local timerQuills			= mod:NewBuffActiveTimer(10, 134380)
local timerQuillsCD			= mod:NewCDCountTimer(62.5, 134380)--variable because he has two other channeled abilities with different cds, so this is cast every 62.5-67 seconds usually after channel of some other spell ends
local timerFlockCD	 		= mod:NewTimer(30, "timerFlockCD", 15746)
local timerFeedYoungCD	 	= mod:NewCDTimer(30, 137528)--30-40 seconds (always 30 unless delayed by other channeled spells)
local timerTalonRakeCD		= mod:NewCDTimer(20, 134366, nil, mod:IsTank() or mod:IsHealer())--20-30 second variation
local timerTalonRake		= mod:NewTargetTimer(60, 134366, nil, mod:IsTank() or mod:IsHealer())
local timerDowndraft		= mod:NewBuffActiveTimer(10, 134370)
local timerDowndraftCD		= mod:NewCDTimer(97, 134370)
local timerFlight			= mod:NewBuffFadesTimer(10, 133755)
local timerPrimalNutriment	= mod:NewBuffFadesTimer(30, 140741)
local timerLessons			= mod:NewBuffFadesTimer(60, 140571, nil, false)

mod:AddBoolOption("RangeFrame", mod:IsRanged())
mod:AddDropdownOption("ShowNestArrows", {"Never", "Northeast", "Southeast", "Southwest", "West", "Northwest", "Guardians"}, "Never", "misc")
--Southwest is inconsistent between 10 and 25 because blizz activates lower SW on 10 man but does NOT activate upper SW (middle is activated in it's place)
--As such, the options have to be coded special so that Southwest sends 10 man to upper middle and sends 25 to actual upper southwest (option text explains this difference)
--West and Northwest are obviously nests that 10 man/LFR never see so the options won't do anything outside of 25 man (thus the 25 man only text)

local nest = 0
local trackedNests = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true }
local flockCount = 0
local quillsCount = 0
local flockName = EJ_GetSectionInfo(7348)

function mod:OnCombatStart(delay)
	nest = 0
	flockCount = 0
	quillsCount = 0
	timerTalonRakeCD:Start(24)
	if self:IsDifficulty("normal10", "heroic10", "lfr25") then
		timerQuillsCD:Start(60-delay, 1)
	else
		timerQuillsCD:Start(42.5-delay, 1)
	end
	timerDowndraftCD:Start(91-delay)
	if self.Options.RangeFrame then
		DBM.RangeCheck:Show(10)
	end
	if self.Options[specWarnFeedPool.option] then--specWarnFeedPool is turned on, since it's off by default, no reason to register high CPU events unless user turns it on
		self:RegisterShortTermEvents(
			"SPELL_PERIODIC_DAMAGE",
			"SPELL_PERIODIC_MISSED"
		)
	end
end

function mod:OnCombatEnd()
	if self.Options.RangeFrame then
		DBM.RangeCheck:Hide()
	end
	self:UnregisterShortTermEvents()
end

function mod:SPELL_AURA_APPLIED(args)
	if args.spellId == 134366 then
		local amount = args.amount or 1
		warnTalonRake:Show(args.destName, amount)
		timerTalonRake:Start(args.destName)
		timerTalonRakeCD:Start()
		if args:IsPlayer() then
			if amount >= 2 then
				specWarnTalonRake:Show(amount)
			end
		else
			if amount >= 1 and not UnitDebuff("player", GetSpellInfo(134366)) and not UnitIsDeadOrGhost("player") then
				specWarnTalonRakeOther:Show(args.destName)
			end
		end
	elseif args.spellId == 133755 and args:IsPlayer() then
		timerFlight:Start()
	elseif args.spellId == 140741 and args:IsPlayer() then
		warnPrimalNutriment:Show(args.amount or 1)
		timerPrimalNutriment:Start()
	elseif args.spellId == 140571 and args:IsPlayer() then
		timerLessons:Start()
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	if args.spellId == 134366 then
		timerTalonRake:Cancel(args.destName)
	elseif args.spellId == 133755 and args:IsPlayer() then
		timerFlight:Cancel()
	elseif args.spellId == 140741 and args:IsPlayer() then
		timerPrimalNutriment:Cancel()
	elseif args.spellId == 140571 and args:IsPlayer() then
		timerLessons:Cancel()
	end
end

function mod:SPELL_PERIODIC_DAMAGE(_, _, _, _, destGUID, _, _, _, spellId)
	if spellId == 138319 and destGUID == UnitGUID("player") and self:AntiSpam(2, 1) then
		specWarnFeedPool:Show()
	end
end
mod.SPELL_PERIODIC_MISSED = mod.SPELL_PERIODIC_DAMAGE

function mod:UNIT_SPELLCAST_CHANNEL_START(uId, _, _, _, spellId)
	if spellId == 137528 then
		warnFeedYoung:Show()
		specWarnFeedYoung:Show()
		if self:IsDifficulty("normal10", "heroic10", "lfr25") then
			timerFeedYoungCD:Start(40)
		else
			timerFeedYoungCD:Start()
		end
	end
end

function mod:UNIT_SPELLCAST_START(uId, _, _, _, spellId)
	if spellId == 134380 then
		quillsCount = quillsCount + 1
		warnQuills:Show(quillsCount)
		specWarnQuills:Show()
		timerQuills:Start()
		if self:IsDifficulty("normal10", "heroic10", "lfr25") then
			timerQuillsCD:Start(81, quillsCount+1)--81 sec normal, sometimes 91s?
		else
			timerQuillsCD:Start(nil, quillsCount+1)
		end
	elseif spellId == 134370 then
		warnDowndraft:Show()
		specWarnDowndraft:Show()
		timerDowndraft:Start()
		if self:IsDifficulty("heroic10", "heroic25") then
			timerDowndraftCD:Start(93)
		else
			timerDowndraftCD:Start()--Todo, confirm they didn't just change normal to 90 as well. in my normal logs this had a 110 second cd on normal
		end
	end
end

function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg, _, _, _, target)
	if msg:find("spell:138923") then--Caws (does not show in combat log, like a lot of stuff this tier) Fortunately easy to detect this way without localizing
		warnCaws:Show()
		--timerCawsCD
	end
end

local nestCoords = {
	[0] = { 47.00, 40.81 },--6
	[1] = { 57.79, 30.15 },--1
	[2] = { 55.14, 60.95 },--2
	[3] = { 45.89, 55.20 },--3
	[4] = { 63.25, 36.04 },--4
	[5] = { 57.46, 59.61 }--5
}

local flockTableLFR = {
	[0] = { loc = L.Upper, dir = { { L.ArrowUpper, L.Middle10 } } },--6
	[1] = { loc = L.Lower, dir = { { L.ArrowLower, L.NorthEast } } },--1
	[2] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthEast } } },--2
	[3] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthWest } } },--3
	[4] = { loc = L.Upper, dir = { { L.ArrowUpper, L.NorthEast } } },--4
	[5] = { loc = L.Upper, dir = { { L.ArrowUpper, L.SouthEast } } },--5
}

local flockTable10 = {
	[1] = { loc = L.Lower, dir = { { L.ArrowLower, L.NorthEast } } },
	[2] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthEast, true } } },
	[3] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthWest } } },
	[4] = { loc = L.Upper, dir = { { L.ArrowUpper, L.NorthEast, true } } },
	[5] = { loc = L.Upper, dir = { { L.ArrowUpper, L.SouthEast } } },
	[6] = { loc = L.Upper, dir = { { L.ArrowUpper, L.Middle10 } } },
	[7] = { loc = L.Lower, dir = { { L.ArrowLower, L.NorthEast } } },
	[8] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthEast, true } } },
	[9] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthWest }, { L.ArrowUpper, L.NorthEast } } },
	[10] = { loc = L.Upper, dir = { { L.ArrowUpper, L.SouthEast } } },
	[11] = { loc = L.Upper, dir = { { L.ArrowUpper, L.Middle10, true } } },
	[12] = { loc = L.Lower, dir = { { L.ArrowLower, L.NorthEast } } },
	[13] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthEast, true } } },
	[14] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthWest }, { L.ArrowUpper, L.NorthEast } } },
	[15] = { loc = L.Upper, dir = { { L.ArrowUpper, L.SouthEast } } },
	[16] = { loc = L.Upper, dir = { { L.ArrowUpper, L.Middle10 } } }
}

local flockTable25N = {
	[1] = { loc = L.Lower, dir = { { L.ArrowLower, L.NorthEast } } },
	[2] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthEast } } },
	[3] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthWest } } },
	[4] = { loc = L.Lower, dir = { { L.ArrowLower, L.West } } },
	[5] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthWest }, { L.ArrowUpper, L.NorthEast } } },
	[6] = { loc = L.Upper, dir = { { L.ArrowUpper, L.SouthEast } } },
	[7] = { loc = L.Upper, dir = { { L.ArrowUpper, L.Middle25 } } },
	[8] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthEast }, { L.ArrowUpper, L.SouthWest } } },
	[9] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthEast }, { L.ArrowUpper, L.NorthWest } } },
	[10] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthEast } } },
	[11] = { loc = L.Lower, dir = { { L.ArrowLower, L.West } } },
	[12] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthWest }, { L.ArrowUpper, L.NorthEast } } },
	[13] = { loc = L.Upper, dir = { { L.ArrowUpper, L.SouthEast } } },
	[14] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthEast }, { L.ArrowUpper, L.Middle25 } } },
	[15] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthEast }, { L.ArrowUpper, L.SouthWest } } },
	[16] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthWest }, { L.ArrowUpper, L.NorthWest } } },
	[17] = { loc = L.Lower, dir = { { L.ArrowLower, L.West } } },
	[18] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthWest }, { L.ArrowUpper, L.NorthEast } } },
	[19] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, DBM_CORE_UNKNOWN }, { L.ArrowUpper, L.SouthEast } } },
	[20] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthEast }, { L.ArrowUpper, L.Middle25 } } }
}

local flockTable25H = {
	[1] = { loc = L.Lower, dir = { { L.ArrowLower, L.NorthEast } } },
	[2] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthEast, true } } },
	[3] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthWest } } },
	[4] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.West }, { L.ArrowUpper, L.NorthEast } } },
	[5] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthWest, true }, { L.ArrowUpper, L.SouthEast } } },
	[6] = { loc = L.Upper, dir = { { L.ArrowUpper, L.Middle25 } } },
	[7] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthEast }, { L.ArrowUpper, L.SouthWest } } },
	[8] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthEast }, { L.ArrowUpper, L.NorthWest, true } } },
	[9] = { loc = L.Lower, dir = { { L.ArrowLower, L.SouthWest } } },
	[10] = { loc = L.UpperAndLower, dir = { { L.ArrowUpper, L.NorthEast }, { L.ArrowLower, L.West } } },
	[11] = { loc = L.UpperAndLower, dir = { { L.ArrowUpper, L.SouthEast, true }, { L.ArrowLower, L.NorthWest } } },
	[12] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.NorthEast }, { L.ArrowUpper, L.Middle25 } } },
	[13] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthEast }, { L.ArrowUpper, L.SouthWest } } },
	[14] = { loc = L.TrippleU, dir = { { L.ArrowUpper, L.NorthEast }, { L.ArrowLower, L.SouthWest, true }, { L.ArrowUpper, L.NorthWest } } },
	[15] = { loc = L.UpperAndLower, dir = { { L.ArrowUpper, L.SouthEast }, { L.ArrowLower, L.West } } },
	[16] = { loc = L.TrippleD, dir = { { L.ArrowLower, L.NorthEast }, { L.ArrowUpper, L.Middle25 }, { L.ArrowLower, L.NorthWest } } },
	[17] = { loc = L.UpperAndLower, dir = { { L.ArrowLower, L.SouthEast, true }, { L.ArrowUpper, L.SouthWest } } },
	[18] = { loc = L.TrippleU, dir = { { L.ArrowUpper, L.NorthEast }, { L.ArrowLower, L.SouthWest }, { L.ArrowUpper, L.NorthWest } } },
	[19] = { loc = L.TrippleD, dir = { { L.ArrowLower, L.NorthWest }, { L.ArrowUpper, L.SouthEast }, { L.ArrowLower, L.NorthEast } } },
	[20] = { loc = L.Upper, dir = { { L.ArrowUpper, DBM_CORE_UNKNOWN, true } } }
}

local function FormatNestLoc(dirs, skip)
	local ret, num, oldnest = "", #dirs, nest
	for i, v in pairs(dirs) do
		nest = nest + 1
		if trackedNests[nest] and mod:IsDifficulty("lfr25", "normal10", "heroic10") and not skip then
			DBM.Arrow:ShowRunTo(nestCoords[nest % 6][1]/100, nestCoords[nest % 6][2]/100, 3, 40)
			print(format("Tracked nest: %d", nest))
		end
		ret = ret .. format("%d-%s %s", nest, v[1], v[2])
		if i ~= num then
			ret = ret .. ", "
		end
	end
	if skip then nest = oldnest end
	return ret
end

local function GetAddLoc(dirs)
	for i, v in pairs(dirs) do
		if v[3] then
			return v
		end
	end
end

local function GetNestPositions(flockC, skip)
	local dir = DBM_CORE_UNKNOWN --direction
	local loc = "" --location
	local add = nil
	if mod:IsDifficulty("lfr25") then
		dir, loc = flockTableLFR[flockC % 6].loc or DBM_CORE_UNKNOWN, FormatNestLoc(flockTableLFR[flockC % 6].dir, skip) or ""
	elseif mod:IsDifficulty("normal10") then
		dir, loc = flockTable10[flockC].loc or DBM_CORE_UNKNOWN, FormatNestLoc(flockTable10[flockC].dir, skip) or ""
	elseif mod:IsDifficulty("heroic10") then
		dir, loc, add = flockTable10[flockC].loc or DBM_CORE_UNKNOWN, FormatNestLoc(flockTable10[flockC].dir, skip) or "", GetAddLoc(flockTable10[flockC].dir)
	elseif mod:IsDifficulty("normal25") then
		dir, loc = flockTable25N[flockC].loc or DBM_CORE_UNKNOWN, FormatNestLoc(flockTable25N[flockC].dir, skip) or ""
	elseif mod:IsDifficulty("heroic25") then
		dir, loc, add = flockTable25H[flockC].loc or DBM_CORE_UNKNOWN, FormatNestLoc(flockTable25H[flockC].dir, skip) or "", GetAddLoc(flockTable25H[flockC].dir)
	end
	return dir, loc, add
end

function mod:CHAT_MSG_MONSTER_EMOTE(msg, _, _, _, target)
	if msg:find(L.eggsHatch) and self:AntiSpam(5, 2) then
		flockCount = flockCount + 1--Now flock set number instead of nest number (for LFR it's both)
		local flockCountText = tostring(flockCount)
		local currentDirection, currentLocation, currentAdd = GetNestPositions(flockCount, false)
		local nextDirection, nextLocation, nextAdd = GetNestPositions(flockCount+1, true)--timer code will probably always stay the same, locations in timer is too much text for a timer.
		if self:IsDifficulty("lfr25", "normal10", "heroic10") then
			timerFlockCD:Show(40, flockCount+1, nextDirection)
		else
			timerFlockCD:Show(30, flockCount+1, nextDirection)
		end
		if self:IsDifficulty("heroic10") then
			if currentAdd then
				specWarnBigBird:Show(currentDirection.." ("..currentLocation..")")
			end
			-- pre-warning 10 sec before Nest Guardian spawn
			if nextAdd then
				specWarnBigBirdSoon:Schedule(30, nextDirection.." ("..nextLocation..")")
			end
		elseif self:IsDifficulty("heroic25") then
			if currentAdd then
				specWarnBigBird:Show(currentAdd.loc.." ("..currentAdd.dir..")")
			end
			-- pre-warning 10 sec before Nest Guardian spawn
			if nextAdd then
				specWarnBigBirdSoon:Schedule(20, nextAdd.loc.." ("..nextAdd.dir..")")
			end
		end
		if currentLocation ~= "" then
			warnFlock:Show(currentDirection, flockName, flockCountText.." ("..currentLocation..")")
			specWarnFlock:Show(currentDirection, flockName, flockCountText.." ("..currentLocation..")")
		else
			warnFlock:Show(currentDirection, flockName, "("..flockCountText..")")
			specWarnFlock:Show(currentDirection, flockName, "("..flockCountText..")")
		end
	end
end
