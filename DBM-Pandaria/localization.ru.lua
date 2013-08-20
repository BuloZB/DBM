if GetLocale() ~= "ruRU" then return end

local L

-----------------------
-- Sha of Anger --
-----------------------
L= DBM:GetModLocalization(691)

L:SetOptionLocalization({
	RangeFrame			= "Показывать динамическое окно проверки дистанции, основанное\nна статусе игроков с дебаффом $spell:119622",
	ReadyCheck			= "Проигрывать звук проверки готовности когда пулят мирового босса (даже если он не является целью)"
})

L:SetMiscLocalization({
	Pull				= "Да… да! Дайте волю своей ярости! Попробуйте меня убить!"
})

-----------------------
-- Salyis --
-----------------------
L= DBM:GetModLocalization(725)

L:SetOptionLocalization({
	ReadyCheck			= "Проигрывать звук проверки готовности когда пулят мирового босса (даже если он не является целью)"
})

L:SetMiscLocalization({
	Pull				= "Принесите мне их трупы!"
})

--------------
-- Oondasta --
--------------
L= DBM:GetModLocalization(826)

L:SetOptionLocalization({
	ReadyCheck			= "Проигрывать звук проверки готовности когда пулят мирового босса (даже если он не является целью)"
})

L:SetMiscLocalization({
	Pull				= "Как вы смеете вмешиваться в наши планы! На этот раз зандаларов не остановить!"
})

---------------------------
-- Nalak, The Storm Lord --
---------------------------
L= DBM:GetModLocalization(814)

L:SetOptionLocalization({
	ReadyCheck			= "Проигрывать звук проверки готовности когда пулят мирового босса (даже если он не является целью)"
})

L:SetMiscLocalization({
	Pull				= "Чувствуете порывы холодного ветра?"
})

---------------------------
-- Chi-ji, The Red Crane --
---------------------------
L= DBM:GetModLocalization(857)

L:SetOptionLocalization({
	BeaconArrow				= "Показывать стрелку DBM когда на ком-то $spell:144473"
})

L:SetMiscLocalization({
	Victory					= "Your hope shines brightly, and even more brightly when you work together to overcome. It will ever light your way in even the darkest of places."
})

------------------------------
-- Yu'lon, The Jade Serpent --
------------------------------
L= DBM:GetModLocalization(858)

--------------------------
-- Niuzao, The Black Ox --
--------------------------
L= DBM:GetModLocalization(859)

---------------------------
-- Xuen, The White Tiger --
---------------------------
L= DBM:GetModLocalization(860)

L:SetMiscLocalization({
	Victory					= "You are strong, stronger even than you realize. Carry this thought with you into the darkness ahead, and let it shield you."
})

------------------------------------
-- Ordos, Fire-God of the Yaungol --
------------------------------------
L= DBM:GetModLocalization(861)
