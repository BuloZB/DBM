local mod	= DBM:NewMod("BrawlRank4", "DBM-Brawlers")
local L		= mod:GetLocalizedStrings()

mod:SetRevision(("$Revision: 8252 $"):sub(12, -3))
--mod:SetCreatureID(60491)
mod:SetModelID(28115)
mod:SetZone()

mod:RegisterEvents(
	"SPELL_CAST_START"
)
