local mod	= DBM:NewMod(332, "DBM-DragonSoul", nil, 187)
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 7225 $"):sub(12, -3))
mod:SetCreatureID(56598)--56427 is Boss, but engage trigger needs the ship which is 56598
mod:SetModelID(39399)
mod:SetZone()
mod:SetUsedIcons()

mod:RegisterCombat("combat")
mod:SetMinCombatTime(20)

mod:RegisterEventsInCombat(
	"SPELL_CAST_START",
	"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"SPELL_SUMMON",
	"SPELL_DAMAGE",
	"SPELL_MISSED",
	"RAID_BOSS_EMOTE",
	"UNIT_DIED",
	"UNIT_SPELLCAST_SUCCEEDED"
)

local warnDrakesLeft				= mod:NewAddsLeftAnnounce("ej4192", 2, 61248)
local warnHarpoon					= mod:NewTargetAnnounce(108038, 2)
local warnReloading					= mod:NewCastAnnounce(108039, 2)
local warnTwilightOnslaught			= mod:NewCountAnnounce(108862, 4)
local warnPhase2					= mod:NewPhaseAnnounce(2, 3)
local warnRoar						= mod:NewSpellAnnounce(109228, 2)
local warnTwilightFlames			= mod:NewSpellAnnounce(108051, 3)
local warnShockwave					= mod:NewTargetAnnounce(108046, 4)
local warnSunder					= mod:NewStackAnnounce(108043, 3, nil, mod:IsTank() or mod:IsHealer())
local warnConsumingShroud			= mod:NewTargetAnnounce(110598)

local specWarnHarpoon				= mod:NewSpecialWarningTarget(108038, false)
local specWarnTwilightOnslaught		= mod:NewSpecialWarningSpell(107588, nil, nil, nil, true)
local specWarnDeckFireCast			= mod:NewSpecialWarningSpell(110095, false, nil, nil, true)
local specWarnDeckFire				= mod:NewSpecialWarningMove(110095)
local specWarnElites				= mod:NewSpecialWarning("SpecWarnElites", mod:IsTank())
local specWarnShockwave				= mod:NewSpecialWarningMove(108046)
local specWarnShockwaveOther		= mod:NewSpecialWarningTarget(108046, false)
local yellShockwave					= mod:NewYell(108046)
local specWarnTwilightFlames		= mod:NewSpecialWarningMove(108076)
local specWarnSunder				= mod:NewSpecialWarningStack(108043, mod:IsTank(), 3)
local specWarnSunderOther			= mod:NewSpecialWarningTarget(108043, mod:IsTank())

local timerCombatStart				= mod:NewTimer(20.5, "TimerCombatStart", 2457)
local timerAdd						= mod:NewTimer(61, "TimerAdd", 107752)
local timerHarpoonCD				= mod:NewCDTimer(48, 108038, nil, mod:IsDps())--CD when you don't fail at drakes
local timerHarpoonActive			= mod:NewBuffActiveTimer(20, 108038, nil, mod:IsDps())--Seems to always hold at least 20 seconds, beyond that, RNG, but you always get at least 20 seconds before they "snap" free.
local timerReloadingCast			= mod:NewCastTimer(10, 108039, nil, mod:IsDps())--You screwed up and let a drake get away, this makes a harpoon gun reload and regrab failed drakes after 10 seconds.
local timerTwilightOnslaught		= mod:NewCastTimer(7, 107588)
local timerTwilightOnslaughtCD		= mod:NewNextCountTimer(35, 107588)
local timerSapperCD					= mod:NewNextTimer(40, "ej4200", nil, nil, nil, 107752)
local timerDegenerationCD			= mod:NewCDTimer(8.5, 109208, nil, mod:IsTank())--8.5-9.5 variation.
local timerBladeRushCD				= mod:NewCDTimer(15.5, 107595)--Experiment, 15.5-20 seemed common for heroic, LFR was a variatable 20-25sec. Just need more data, a lot more.
local timerBroadsideCD				= mod:NewNextTimer(90, 110153)
local timerRoarCD					= mod:NewCDTimer(19, 109228)--19~22 variables (i haven't seen any logs where this wasn't always 21.5, are 19s on WoL somewhere?)
local timerTwilightFlamesCD			= mod:NewNextTimer(8, 108051)
local timerShockwaveCD				= mod:NewCDTimer(23, 108046)
local timerDevastateCD				= mod:NewCDTimer(8.5, 108042, nil, mod:IsTank())
local timerSunder					= mod:NewTargetTimer(30, 108043, nil, mod:IsTank() or mod:IsHealer())
local timerConsumingShroud			= mod:NewCDTimer(30, 110598)
local timerTwilightBreath			= mod:NewCDTimer(20.5, 110213, nil, mod:IsTank() or mod:IsHealer())

local twilightOnslaughtCountdown	= mod:NewCountdown(35, 107588)
local berserkTimer					= mod:NewBerserkTimer(240)

mod:AddBoolOption("SetTextures", false)--Disable projected textures in phase 1, because no harmful spells use them in phase 1, but friendly spells make the blade rush lines harder to see.

local phase2Started = false
local lastFlames = 0
local addsCount = 0
local drakesCount = 6
local ignoredHarpoons = 0
local twilightOnslaughtCount = 0
local CVAR = false
--local recentlyReloaded = false

local function Phase2Delay()
	mod:UnscheduleMethod("AddsRepeat")
	timerAdd:Cancel()
	timerTwilightOnslaughtCD:Cancel()
	twilightOnslaughtCountdown:Cancel()
	timerBroadsideCD:Cancel()
	timerSapperCD:Cancel()
	timerRoarCD:Start(10)
	timerTwilightFlamesCD:Start(12)
	timerShockwaveCD:Start(13)--13-16 second variation
	if mod:IsDifficulty("heroic10", "heroic25") then
		timerConsumingShroud:Start(45)	-- 45seconds once P2 starts?
	end
	if not mod:IsDifficulty("lfr25") then--Assumed, but i find it unlikely a 4 min berserk timer will be active on LFR
		berserkTimer:Start()
	end
	if mod.Options.SetTextures and not GetCVarBool("projectedTextures") and CVAR then--Confirm we turned them off in phase 1 before messing with anything.
		SetCVar("projectedTextures", 1)--Turn them back on for phase 2 if we're the ones that turned em off on pull.
	end
end

function mod:ShockwaveTarget()
	local targetname = self:GetBossTarget(56427)
	if not targetname then return end
	warnShockwave:Show(targetname)
	if targetname == UnitName("player") then
		specWarnShockwave:Show()
		yellShockwave:Yell()
	else
		specWarnShockwaveOther:Show(targetname)
	end
end

function mod:AddsRepeat() -- it seems to be adds summon only 3 times. needs more review
	if addsCount < 2 then -- fix logical error
		addsCount = addsCount + 1
		specWarnElites:Show()
		timerAdd:Start()
		self:ScheduleMethod(61, "AddsRepeat")
		--Experimental harpoon stuff. Think it actually works this way.
		--since the elites don't fire anything in logs unless you target every Twilight Elite Dreads's Drake before it ejects him to get log time stamps
--		"<15.9> [UNIT_SPELLCAST_SUCCEEDED] Twilight Assault Drake:Possible Target<nil>:target:Eject Passenger 1::0:60603", -- [180]
--		The two useless casts are ignored because they actually fail, every pull, the first harpoons fail once (and out of order too not at same time), and relaunch synced up after.
--		"<35.5> [CLEU] SPELL_AURA_APPLIED#false#0xF150DD6900007D9A#Skyfire Harpoon Gun#2584#0#0xF150DE1700008B45#Twilight Assault Drake#133704#0#108038#Harpoon#1#BUFF", -- [2369]
		if addsCount == 1 then
			timerHarpoonCD:Start(20)--20 seconds after first elites (Confirmed)
--		Pug was bad and i got distracted and didn't target the drake before it cast "Eject Passenger". 76.9 assumed based on established "elites" cd.
--		"<82.9> [CLEU] SPELL_AURA_APPLIED#false#0xF150DD6900007D4A#Skyfire Harpoon Gun#2584#0#0xF150DD0B00008C0E#Twilight Assault Drake#2632#0#108038#Harpoon#1#BUFF", -- [12268]
		elseif addsCount == 2 then
			timerHarpoonCD:Start(6)--6 in this log. Maybe 2nd and 3rd sets are both a 6-7 variation and only first is 20 seconds after? Then again the eject passenger time was assumed.
--		"<138.7> [UNIT_SPELLCAST_SUCCEEDED] Twilight Assault Drake:Possible Target<nil>:target:Eject Passenger 1::0:60603", -- [24162]
--		"<145.6> [CLEU] SPELL_AURA_APPLIED#false#0xF150DD6900007D9A#Skyfire Harpoon Gun#2584#0#0xF150DE1700008CB9#Twilight Assault Drake#2632#0#108038#Harpoon#1#BUFF", -- [25407]
		elseif addsCount == 3 then
			timerHarpoonCD:Start(7)--7 in this log. Maybe it's 6-7 like 2nd set?
		end
	end
end

function mod:OnCombatStart(delay)
	phase2Started = false
	lastFlames = 0
	addsCount = 0
	drakesCount = 6
	ignoredHarpoons = 0
	twilightOnslaughtCount = 0
	CVAR = false
--	recentlyReloaded = false
	timerCombatStart:Start(-delay)
	timerAdd:Start(22.8-delay)
	self:ScheduleMethod(22.8-delay, "AddsRepeat")
	timerTwilightOnslaughtCD:Start(48-delay, 1)
	twilightOnslaughtCountdown:Start(48-delay)
	if self:IsDifficulty("heroic10", "heroic25") then
		timerBroadsideCD:Start(57-delay)
	end
	if not self:IsDifficulty("lfr25") then--No sappers in LFR
		timerSapperCD:Start(69-delay)
	end
	if DBM.BossHealth:IsShown() then
		local shipname = EJ_GetSectionInfo(4202)
		DBM.BossHealth:Clear()
		DBM.BossHealth:AddBoss(56598, shipname)
	end
	if self.Options.SetTextures and GetCVarBool("projectedTextures") then--This is only true if projected textures were on when we pulled and option to control setting is also on.
		CVAR = true--so set this variable to true, which means we are allowed to mess with users graphics settings
		SetCVar("projectedTextures", 0)
	end
end

function mod:OnCombatEnd()
	if self.Options.SetTextures and not GetCVarBool("projectedTextures") and CVAR then--Only turn them back on if they are off now, but were on when we pulled, and the setting is enabled.
		SetCVar("projectedTextures", 1)
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(107588) then
		twilightOnslaughtCount = twilightOnslaughtCount + 1
		warnTwilightOnslaught:Show(twilightOnslaughtCount)
		specWarnTwilightOnslaught:Show()
		timerTwilightOnslaught:Start()
		timerTwilightOnslaughtCD:Start(nil, twilightOnslaughtCount + 1)
		twilightOnslaughtCountdown:Start()
	elseif args:IsSpellID(108046) then
		self:ScheduleMethod(0.2, "ShockwaveTarget")
		timerShockwaveCD:Start()
	elseif args:IsSpellID(110210, 110213) then
		timerTwilightBreath:Start()
	elseif args:IsSpellID(108039) then
--		recentlyReloaded = true
		warnReloading:Show()
		timerReloadingCast:Start(args.sourceGUID)
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(108044, 109228, 109229, 109230) then
		warnRoar:Show()
		timerRoarCD:Start()
	elseif args:IsSpellID(108042) then
		timerDevastateCD:Start()
	elseif args:IsSpellID(107558, 108861, 109207, 109208) then
		timerDegenerationCD:Start(args.sourceGUID)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(108043) then
		warnSunder:Show(args.destName, args.amount or 1)
		timerSunder:Start(args.destName)
		if args:IsPlayer() then
			if (args.amount or 1) >= 3 then
				specWarnSunder:Show(args.amount)
			end
		else
			if (args.amount or 1) >= 2 and not UnitDebuff("player", GetSpellInfo(108043)) then--Other tank has 2 or more sunders and you have none.
				specWarnSunderOther:Show(args.destName)--So nudge you to taunt it off other tank already.
			end
		end
	elseif args:IsSpellID(108038) then
		if ignoredHarpoons < 3 then--First two harpoons of fight are bugged, they fire early, apply to drake, even though they missed, then refire. we simply ignore first 2 bad casts to avoid spam and confusion.
			ignoredHarpoons = ignoredHarpoons + 1
		else--We are passed the 2 useless ones, do everything as normal now.
			warnHarpoon:Show(args.destName)
			specWarnHarpoon:Show(args.destName)
--[[		if not recentlyReloaded then--No old drakes are up when this was cast, so start a fresh valid 48 second bar.
				timerHarpoonCD:Start(args.sourceGUID)
			else
				timerHarpoonCD:Cancel()--Cancel all harpoon bars since the "Reloading" cast finished before old drake died, which alters and ruins the bar Cds this drake cycle.
			end--]]
			if self:IsDifficulty("heroic10", "heroic25") then
				timerHarpoonActive:Start(nil, args.destGUID)
			elseif self:IsDifficulty("normal10", "normal25") then
				timerHarpoonActive:Start(25, args.destGUID)
			end
		end
	elseif args:IsSpellID(108040) and not phase2Started then--Goriona is being shot by the ships Artillery Barrage (phase 2 trigger)
		self:Schedule(10, Phase2Delay)--It seems you can still get phase 1 crap until blackhorn is on the deck itself(ie his yell 10 seconds after this trigger) so we delay canceling timers.
		phase2Started = true
		warnPhase2:Show()--We still warn phase 2 here though to get into position, especially since he can land on deck up to 5 seconds before his yell.
		timerCombatStart:Start(5)--5-8 seems variation, we use shortest.
		if DBM.BossHealth:IsShown() then
			DBM.BossHealth:AddBoss(56427, L.name)
		end
	elseif args:IsSpellID(110598, 110214) then
		warnConsumingShroud:Show(args.destName)
		timerConsumingShroud:Start()
	end
end		
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_SUMMON(args)
	if args:IsSpellID(108051, 109216, 109217, 109218) then
		warnTwilightFlames:Show()--Target scanning? will need to put drake on focus and see
		timerTwilightFlamesCD:Start()
	end
end

function mod:SPELL_DAMAGE(args)
	if args:IsSpellID(108076, 109222, 109223, 109224) then
		if args:IsPlayer() and GetTime() - lastFlames > 3  then
			specWarnTwilightFlames:Show()
			lastFlames = GetTime()
		end
	elseif args:IsSpellID(110095) then
		if args:IsPlayer() and GetTime() - lastFlames > 3  then
			specWarnDeckFire:Show()
			lastFlames = GetTime()
		end
	end
end
mod.SPELL_MISSED = mod.SPELL_DAMAGE

function mod:RAID_BOSS_EMOTE(msg)
	if msg == L.SapperEmote or msg:find(L.SapperEmote) then
		timerSapperCD:Start()
	elseif msg == L.Broadside or msg:find(L.Broadside) then
		timerBroadsideCD:Start()
	elseif msg == L.DeckFire or msg:find(L.DeckFire) then
		specWarnDeckFireCast:Show()
	elseif msg == L.GorionaRetreat or msg:find(L.GorionaRetreat) then
		timerTwilightBreath:Cancel()
		timerConsumingShroud:Cancel()
		timerTwilightFlamesCD:Cancel()
	end
end


--[[Useful reg expressions for WoL
spellid = 108038 or fulltype = UNIT_DIED and (targetMobId = 56855 or targetMobId = 56587) or spellid = 108039
spellid = 108038 and fulltype = SPELL_CAST_START or fulltype = UNIT_DIED and (targetMobId = 56855 or targetMobId = 56587) or spellid = 108039
--]]

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 56427 then--Boss
		DBM:EndCombat(self)
	elseif cid == 56848 or cid == 56854 then--Humanoids
		timerBladeRushCD:Cancel(args.sourceGUID)
		timerDegenerationCD:Cancel(args.sourceGUID)
	elseif cid == 56855 or cid == 56587 then--Small Drakes (maybe each side has a unique ID? this could be useful in further filtering which harpoon is which side.
		drakesCount = drakesCount - 1
		warnDrakesLeft:Show(drakesCount)
		timerHarpoonActive:Cancel(args.sourceGUID)
--[[		if drakesCount == 4 or drakesCount == 2 then
			recentlyReloaded = false
		end--]]
	end
end

function mod:UNIT_SPELLCAST_SUCCEEDED(uId, spellName)
	if spellName == GetSpellInfo(107594) then--Blade Rush, cast start is not detectable, only cast finish, can't use target scanning, or pre warn (ie when the lines go out), only able to detect when they actually finish rush
		self:SendSync("BladeRush", UnitGUID(uId))
	end
end

function mod:OnSync(msg, sourceGUID)
	if msg == "BladeRush" then
		if self:IsDifficulty("heroic10", "heroic25") then
			timerBladeRushCD:Start(sourceGUID)
		else
			timerBladeRushCD:Start(20, sourceGUID)--assumed based on LFR, which seemed to have a 20-25 variation, not 15-20
		end
	end
end