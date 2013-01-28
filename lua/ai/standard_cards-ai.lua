function SmartAI:canAttack(enemy, attacker, nature)
	attacker = attacker or self.player
	nature = nature or sgs.DamageStruct_Normal
	if #self.enemies == 1 or self:hasSkills("jueqing") then return true end
	if self:getDamagedEffects(enemy, attacker) or (enemy:getHp() > getBestHp(enemy) and #self.enemies > 1) or not sgs.isGoodTarget(enemy, self.enemies) then return false end
	if self:objectiveLevel(enemy) <= 3 or self:cantbeHurt(enemy) or not self:damageIsEffective(enemy, nature , attacker) then return false end
	if nature ~= sgs.DamageStruct_Normal and enemy:isChained() and not self:isGoodChainTarget(enemy) then return false end
	return true
end

local function hasExplicitRebel(room)
	for _, player in sgs.qlist(room:getAllPlayers()) do
		if sgs.isRolePredictable() and sgs.evaluatePlayerRole(player) == "rebel" then return true end
		if sgs.compareRoleEvaluation(player, "rebel", "loyalist") == "rebel" then return true end
	end
	return false
end

function sgs.isGoodHp(player)
	local goodHp = player:getHp() > 1 or getCardsNum("Peach", player) >= 1 or getCardsNum("Analeptic", player) >= 1
					or (player:hasSkill("buqu") and player:getPile("buqu"):length() <= 4)
					or (player:hasSkill("niepan") and player:getMark("@nirvana") > 0)
					or (player:hasSkill("fuli") and player:getMark("@laoji") > 0)
	if goodHp then
		return goodHp
	else
		for _, p in sgs.qlist(global_room:getOtherPlayers(player)) do
			if sgs.compareRoleEvaluation(p,"rebel","loyalist") == sgs.compareRoleEvaluation(player,"rebel","loyalist")
					and getCardsNum("Peach", p) > 0 and not global_room:getCurrent():hasSkill("wansha") then
				return true
			end
		end
		return false
	end
end

function sgs.isGoodTarget(player, targets)
	local arr = {"jieming", "yiji", "guixin", "fangzhu", "neoganglie", "miji"}
	local m_skill = false
	local attacker = global_room:getCurrent()
	if attacker:hasSkill("jueqing") then return true end

	if targets and type(targets) == "table" then
		if #targets == 1 then return true end
		local foundtarget = false
		for i = 1, #targets, 1 do
			if sgs.isGoodTarget(targets[i]) then
				foundtarget = true
				break
			end
		end
		if not foundtarget then return true end
	end

	for _, masochism in ipairs(arr) do
		if player:hasSkill(masochism) then
			if masochism == "miji" and player:isWounded() then
				m_skill = false
			else
				m_skill = true
				break
			end
		end
	end

	if player:hasSkill("huilei") and player:getHp() == 1 then
		if attacker:getHandcardNum() >= 4 then return false end
		return sgs.compareRoleEvaluation(player, "rebel", "loyalist") == "rebel"
	end

	if player:hasSkill("wuhun") and (attacker:isLord() or player:getHp() <= 2) then
		return false
	end

	if player:hasLordSkill("shichou") and player:getMark("@hate") == 0 then
		for _, p in sgs.qlist(player:getRoom():getOtherPlayers(player)) do
			if p:getMark("@hate_" .. player:objectName()) > 0 and p:getMark("@hate_to") > 0 then
				return false
			end
		end
	end

	if player:hasSkill("hunzi") and player:getMark("hunzi") == 0 and player:isLord() and player:getHp() < 3 then
		return false
	end

	if (m_skill or (player:hasSkill("fenyong") and player:hasSkill("xuehen"))) and sgs.isGoodHp(player) then
		return false
	else
		return true
	end
end

function sgs.getDefenseSlash(player)
	local attacker = global_room:getCurrent()
	local defense = getCardsNum("Jink", player)

	local knownJink = getKnownCard(player, "Jink", true)
	if sgs.card_lack[player:objectName()]["Jink"] == 1 and knownJink == 0 then defense = 0 end
 	defense = defense + knownJink * 1.2

	if player:hasArmorEffect("eight_diagram") or player:hasArmorEffect("bazhen") then
		hasEightDiagram = true
	end

	local m = sgs.masochism_skill:split("|")
	for _, masochism in ipairs(m) do
		if player:hasSkill(masochism) and sgs.isGoodHp(player) then
			defense = defense + 1.3
		end
	end

	if hasEightDiagram then
		defense = defense + 1.5
		if player:hasSkill("tiandu") then defense = defense + 0.6 end
		if player:hasSkill("guicai") or player:hasSkill("huanshi") then defense = defense + 0.3 end
	end

	if not sgs.isGoodTarget(player) then
		defense = defense + 10
	end
	
	if player:hasSkill("rende") and player:getHp() > 2 then
		defense = defense + 3
 	end
	
	if player:hasSkill("tuntian") and getCardsNum("Jink", player) > 0 then
		defense = defense + 1.5  
	end

	local hujiaJink = 0
	if player:hasLordSkill("hujia") then
			local lieges = global_room:getLieges("wei", player)
			for _, liege in sgs.qlist(lieges) do
				if sgs.compareRoleEvaluation(liege,"rebel","loyalist") == sgs.compareRoleEvaluation(player,"rebel","loyalist") then
					hujiaJink = hujiaJink + getCardsNum("Jink", liege)
					if liege:hasArmorEffect("eight_diagram") then hujiaJink=hujiaJink + 0.8 end
				end
			end
			defense = defense + hujiaJink
	end

	if player:getHp() > getBestHp(player) then defense = defense + 1.3 end
	if player:hasSkill("tianxiang") and player:getHandcardNum() > 2 then defense = defense + player:getHandcardNum() * 0.5 end

	if player:getHp() <= 2 then
		defense = defense - 0.4
	end

	local playernum = global_room:alivePlayerCount()
	if (player:getSeat() - attacker:getSeat()) % playernum >= playernum - 2 and playernum > 3 and player:getHandcardNum() <= 2 and player:getHp() <= 2 then
		defense = defense - 0.4
	end

	if player:getHandcardNum() == 0 and hujiaJink == 0 and not player:hasSkill("kongcheng") then
		if player:getHp() <= 1 then defense = defense - 1 end
		if player:getHp() == 2 then defense = defense - 0.5 end
		if not hasEightDiagram then defense = defense - 2 end
		if attacker:hasWeapon("guding_blade") and not player:hasArmorEffect("silver_lion") then
			defense = defense - 1
		end
	end

	local has_fire_slash = 0
	local cards = sgs.QList2Table(attacker:getHandcards())
	for i = 1, #cards, 1 do
		if cards[i]:objectName() == "slash" then
			if attacker:hasWeapon("fan") then
				has_fire_slash = 1
				break
			elseif attacker:hasSkill("lihuo") then
				has_fire_slash = 2
				break
			end
		end
	end

	if player:hasArmorEffect("vine") and has_fire_slash > 0 then
		defense = defense - 0.6 / has_fire_slash
	end

	if player:isLord() then
		defense = defense - 0.4
		if sgs.isLordInDanger() then defense = defense - 0.7 end
	end

	if (sgs.ai_chaofeng[player:getGeneralName()] or 0) >= 3 then
		defense = defense - math.max(6, (sgs.ai_chaofeng[player:getGeneralName()] or 0)) * 0.035
 	end

	if not player:faceUp() then defense = defense - 0.35 end

	if player:containsTrick("indulgence") and not player:containsTrick("YanxiaoCard") then defense = defense - 0.15 end
	if player:containsTrick("supply_shortage") and not player:containsTrick("YanxiaoCard") then defense = defense - 0.15 end

	if not hasEightDiagram then
		if player:hasSkill("jijiu") then defense = defense - 3 end
		if player:hasSkill("dimeng") then defense = defense - 2.5 end
		if player:hasSkill("guzheng") and knownJink == 0 then defense = defense - 2.5 end
		if player:hasSkill("qiaobian") then defense = defense - 2.4 end
		if player:hasSkill("jieyin") then defense = defense - 2.3 end
		if player:hasSkill("lijian") then defense = defense - 2.2 end
		if player:hasSkill("miji") and player:isWounded() then defense = defense - 1.5 end
	end
	return defense
end

sgs.ai_compare_funcs["defenseSlash"] = function(a, b)
	return sgs.getDefenseSlash(a) < sgs.getDefenseSlash(b)
end

function SmartAI:slashProhibit(card, enemy)
	card = card or sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
	for _, askill in sgs.qlist(enemy:getVisibleSkillList()) do
		local filter = sgs.ai_slash_prohibit[askill:objectName()]
		if filter and type(filter) == "function" and filter(self, enemy, card) then return true end
	end

	if self:isFriend(enemy) then
		if card:isKindOf("FireSlash") or self.player:hasSkill("lihuo") or self.player:hasWeapon("fan") then
			if self:isEquip("Vine", enemy) and not (enemy:isChained() and self:isGoodChainTarget(enemy)) then return true end
		end
		if enemy:isChained() and card:isKindOf("NatureSlash") and (not self:isGoodChainTarget(enemy) and not self.player:hasSkill("jueqing")) and
			self:slashIsEffective(card, enemy) then return true end
		if getCardsNum("Jink", enemy) == 0 and enemy:getHp() < 2 and self:slashIsEffective(card, enemy) then return true end
		if enemy:isLord() and self:isWeak(enemy) and self:slashIsEffective(card, enemy) then return true end
		if self:isEquip("GudingBlade") and enemy:isKongcheng() then return true end
	else
		if enemy:isChained() and not self:isGoodChainTarget(enemy) and not self.player:hasSkill("jueqing") and self:slashIsEffective(card, enemy)
			and card:isKindOf("NatureSlash") then
			return true
		end
	end

	return self.room:isProhibited(self.player, enemy, card) or not self:slashIsEffective(card, enemy)
end

function SmartAI:canLiuli(other, another)
	if not other:hasSkill("liuli") then return false end
	local n = other:getHandcardNum()
	if n > 0 and (other:distanceTo(another) <= other:getAttackRange()) then return true
	elseif other:getWeapon() and other:getOffensiveHorse() and (other:distanceTo(another) <= other:getAttackRange()) then return true
	elseif other:getWeapon() or other:getOffensiveHorse() then return other:distanceTo(another) <= 1
	else return false end
end

function SmartAI:slashIsEffective(slash, to)
	if not slash or not to then self.room:writeToConsole(debug.traceback()) end
	if to:hasSkill("zuixiang") and to:isLocked(slash) then return false end
	if to:hasSkill("yizhong") and not to:getArmor() then
		if slash:isBlack() then
			return false
		end
	end
	if (to:getMark("@fenyong") > 0 or to:getMark("@late") > 0) and not self.player:hasSkill("jueqing") then
		return false
	end

	local natures = {
		Slash = sgs.DamageStruct_Normal,
		FireSlash = sgs.DamageStruct_Fire,
		ThunderSlash = sgs.DamageStruct_Thunder,
	}

	if not slash then self.room:writeToConsole(debug.traceback()) end
	local nature = natures[slash:getClassName()]
	if not self:damageIsEffective(to, nature) then return false end

	local armor = to:getArmor()
	if armor and to:hasArmorEffect(armor:objectName()) then
		if armor:objectName() == "renwang_shield" then
			return not slash:isBlack()
		elseif armor:objectName() == "vine" then
			return nature ~= sgs.DamageStruct_Normal or self.player:hasWeapon("fan") or (self.player:hasSkill("lihuo") and not self:isWeak())
		end
	end

	return true
end

function SmartAI:slashIsAvailable(player)
	player = player or self.player
	local slash = self:getCard("Slash", player)
	if not slash or not slash:isKindOf("Slash") then slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0) end
	assert(slash)
	return slash:isAvailable(player)
end

function SmartAI:useCardSlash(card, use)
	if not self:slashIsAvailable() then return end
	local basicnum = 0
	local cards = self.player:getCards("he")
	cards = sgs.QList2Table(cards)
	for _, acard in ipairs(cards) do
		if acard:getTypeId() == sgs.Card_TypeBasic and not acard:isKindOf("Peach") then basicnum = basicnum + 1 end
	end
	local no_distance = (1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, card) > 50)
	self.slash_targets = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, card)

	self.predictedRange = self.player:getAttackRange()

	local rangefix = 0
	if card:isVirtualCard() then
		if self.player:getWeapon() and card:getSubcards():contains(self.player:getWeapon():getEffectiveId()) then
			if self.player:getWeapon():getClassName() ~= "Weapon" then
				rangefix = sgs.weapon_range[self.player:getWeapon():getClassName()] - 1
			end
		end
		if self.player:getOffensiveHorse() and card:getSubcards():contains(self.player:getOffensiveHorse():getEffectiveId()) then
			rangefix = rangefix + 1
		end
	end

	if self.player:hasSkill("qingnang") and self:isWeak() and self:getOverflow() == 0 then return end
	local huatuo = self.room:findPlayerBySkillName("jijiu")
	for _, friend in ipairs(self.friends_noself) do
		local slash_prohibit = false
		slash_prohibit = self:slashProhibit(card, friend)
		if (self.player:hasSkill("pojun") and friend:getHp() > 4 and getCardsNum("Jink", friend) == 0
			and friend:getHandcardNum() < 3)
		or self:getDamagedEffects(friend, self.player)
		or (friend:hasSkill("leiji") and not self.player:hasFlag("luoyi") and self:hasSuit("spade", true, friend)
			and (getKnownCard(friend, "Jink", true) >= 1 or (not self:isWeak(friend) and self:isEquip("EightDiagram", friend)))
		and (hasExplicitRebel(self.room) or not friend:isLord()))
		or (friend:isLord() and self.player:hasSkill("guagu") and friend:getLostHp() >= 1 and getCardsNum("Jink", friend) == 0)
		or (friend:hasSkill("jieming") and self.player:hasSkill("rende") and (huatuo and self:isFriend(huatuo)))
		then
			if not slash_prohibit then
				if ((self.player:canSlash(friend, card, not no_distance, rangefix)) or
					(use.isDummy and (self.player:distanceTo(friend, rangefix) <= self.predictedRange))) and
					self:slashIsEffective(card, friend) then
					use.card = card
					if use.to then
						if use.to:length() == self.slash_targets then
							if self.player:hasSkill("duanbing") then
								if self.player:distanceTo(friend, rangefix) == 1 then
									use.to:append(friend)
								end
							else
								use.to:append(friend)
							end
						else
							use.to:append(friend)
						end
						self:speak("hostile", self.player:isFemale())
						if self.slash_targets <= use.to:length() then return end
					end
				end
			end
		end
	end

	local targets = {}
	self:sort(self.enemies, "defenseSlash")
	for _, enemy in ipairs(self.enemies) do
		if not self:slashProhibit(card, enemy) and sgs.isGoodTarget(enemy, self.enemies) then table.insert(targets, enemy) end
	end

	for _, target in ipairs(targets) do
		local canliuli = false
		for _, friend in ipairs(self.friends_noself) do
			if self:canLiuli(target, friend) and self:slashIsEffective(card, friend) and #targets > 1 and friend:getHp() < 3 then canliuli = true end
		end
		if (self.player:canSlash(target, card, not no_distance, rangefix) or
		(use.isDummy and self.predictedRange and (self.player:distanceTo(target) <= self.predictedRange))) and
		self:objectiveLevel(target) > 3
		and self:slashIsEffective(card, target) and
		not (target:hasSkill("xiangle") and basicnum < 2) and not canliuli and
		not (not self:isWeak(target) and #self.enemies > 1 and #self.friends > 1 and self.player:hasSkill("keji")
			and self:getOverflow() > 0 and not self:isEquip("Crossbow")) then
			-- fill the card use struct
			local usecard = card
			if not use.to or use.to:isEmpty() then
				local equips = self:getCards("EquipCard", self.player, "h")
				for _, equip in ipairs(equips) do
					local callback = sgs.ai_slash_weaponfilter[equip:objectName()]
					if callback and type(callback) == "function" and callback(target, self) and
						self.player:distanceTo(target) <= (sgs.weapon_range[equip:getClassName()] or 0) then
						self:useEquipCard(equip, use)
						if use.card then return end
					end
				end
				if target:isChained() and self:isGoodChainTarget(target) and not use.card then
					if self:isEquip("Crossbow") and card:isKindOf("NatureSlash") then
						local slashes = self:getCards("Slash")
						for _, slash in ipairs(slashes) do
							if not slash:isKindOf("NatureSlash") and self:slashIsEffective(slash, target)
								and not self:slashProhibit(slash, target) then
								usecard = slash
								break
							end
						end
					elseif not card:isKindOf("NatureSlash") then
						local slash = self:getCard("NatureSlash")
						if slash and self:slashIsEffective(slash, target) and not self:slashProhibit(slash, target) then usecard = slash end
					end
				end
				local anal = self:searchForAnaleptic(use, target, card)
				if anal and not self:isEquip("SilverLion", target) and not self:isWeak() then
					if anal:getEffectiveId() ~= card:getEffectiveId() then use.card = anal return end
				end
			end
			use.card = use.card or usecard
			if use.to and not use.to:contains(target) then
				if use.to:length() == self.slash_targets then
					if self.player:hasSkill("duanbing") then
						if self.player:distanceTo(target) == 1 then
							use.to:append(target)
						end
					else
						use.to:append(target)
					end
				else
						use.to:append(target)
				end
				if self.slash_targets <= use.to:length() then return end
			end
		end
	end
end

sgs.ai_skill_use.slash = function(self, prompt)
	local slash = self:getCard("Slash")
	local no_distance_limit = self.player:hasFlag("slashNoDistanceLimit")
	if not slash then return "." end
	for _, enemy in ipairs(self.enemies) do
		if self.player:canSlash(enemy, slash, not no_distance_limit) and not self:slashProhibit(slash, enemy)
		and self:slashIsEffective(slash, enemy) and not (self.player:hasFlag("slashTargetFix") and not enemy:hasFlag("SlashAssignee")) then
			return ("%s->%s"):format(slash:toString(), enemy:objectName())
		end
	end
	return "."
end

sgs.ai_skill_playerchosen.zero_card_as_slash = function(self, targets)
	local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
	local targetlist = sgs.QList2Table(targets)
	local arrBestHp, canAvoidSlash = {}, {}
	self:sort(targetlist, "defenseSlash")
	for _, target in ipairs(targetlist) do
		if self:isEnemy(target) and not self:slashProhibit(slash, target) and sgs.isGoodTarget(target, targetlist) then
			if self:slashIsEffective(slash, target) then
				if target:getHp() > getBestHp(target) then
					table.insert(arrBestHp, target)
				else
					return target
				end
			else
				table.insert(canAvoidSlash, target)
			end
		end
	end
	for i = #targetlist, 1, -1 do
		local target = targetlist[i]
		if not self:slashProhibit(slash, target) then
			if self:slashIsEffective(slash, target) then
				if self:isFriend(target) and (target:getHp() > getBestHp(target) or self:getDamagedEffects(target,self.player)) then
					return target
				end
			else
				table.insert(canAvoidSlash,target)
			end
		end
	end
	if #canAvoidSlash > 0 then return canAvoidSlash[1] end
	if #arrBestHp > 0 then return arrBestHp[1] end
	return targetlist[#targetlist]
end

sgs.ai_card_intention.Slash = function(self, card, from, tos)
	for _, to in ipairs(tos) do
		local value = 80
		if sgs.ai_collateral then sgs.ai_collateral = false value = 0 end

		if sgs.ai_leiji_effect then
			if from and from:hasSkill("liegong") then return end
			sgs.ai_leiji_effect = false
			if sgs.ai_pojun_effect then
				value = value / 1.5
			else
				--value = -value / 1.5
				value = 0
			end
		end
		speakTrigger(card, from, to)
		if to:hasSkill("yiji") then
			-- value = value*(2-to:getHp()) / 1.1
			value = math.max(value*(2-to:getHp()) / 1.1, 0)
		end
		if from:hasSkill("pojun") and to:getHp() > 3 then value = 0 end
		sgs.updateIntention(from, to, value)
	end
end

sgs.ai_skill_choice.slash_extra_targets = function(self, choices)
	return "no"
end

sgs.ai_skill_cardask["slash-jink"] = function(self, data, pattern, target)
	local effect = data:toSlashEffect()
	local cards = sgs.QList2Table(self.player:getHandcards())
	if (not target or self:isFriend(target)) and effect.slash:hasFlag("nosjiefan-slash") then return "." end
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) and not target:hasSkill("qianxi") then return "." end
	--if not target then self.room:writeToConsole(debug.traceback()) end
	if not target then return end
	if self:isFriend(target) then
		if not target:hasSkill("jueqing") and not target:hasSkill("qianxi") then
			if target:hasSkill("rende") and self.player:hasSkill("jieming") then return "." end
			if target:hasSkill("pojun") and not self.player:faceUp() then return "." end
			if (target:hasSkill("jieyin") and (not self.player:isWounded()) and self.player:isMale()) and not self.player:hasSkill("leiji") then return "." end
			if self.player:isChained() and self:isGoodChainTarget(self.player) then return "." end
		end
	else
		if not self:hasHeavySlashDamage(target, effect.slash) then
			if target:hasSkill("mengjin") and not target:hasSkill("qianxi") then
				if self:hasSkills("jijiu|qingnang") and self.player:getCards("he"):length() > 1 then return "." end
				if self:canUseJieyuanDecrease(target) then return "." end
				if self:getCardsNum("Peach") > 0 and not self.player:hasSkill("tuntian") and not self:willSkipPlayPhase() then
					return "."
				end
			end
		end
		if not (self.player:getHandcardNum() == 1 and self:hasSkills(sgs.need_kongcheng)) and not target:hasSkill("qianxi") then
			if self:isEquip("Axe", target) then
				if self:hasSkills(sgs.lose_equip_skill, target) and target:getEquips():length() > 1 then return "." end
				if target:getHandcardNum() - target:getHp() > 2 then return "." end
			elseif self:isEquip("Blade", target) then
				if ((effect.slash:isKindOf("FireSlash") 
					and not target:hasSkill("jueqing") 
					and (self.player:hasArmorEffect("vine") or self:getMark("@gale") > 0))
					or self:hasHeavySlashDamage(target, effect.slash)) then
				elseif self:getCardsNum("Jink") <= getCardsNum("Slash", target) or self:hasSkills("jijiu|qingnang") or self:canUseJieyuanDecrease(target) then
					return "."
				end
			end
		end
	end
	local bgm_zhangfei = self.room:findPlayerBySkillName("dahe")
	if bgm_zhangfei and bgm_zhangfei:isAlive() and self.player:hasFlag("dahe") then
		for _, card in ipairs(self:getCards("Jink")) do
			if card:getSuit() == sgs.Card_Heart then
				return card:getId()
			end
		end
		return "."
	end
end

sgs.dynamic_value.damage_card.Slash = true

sgs.ai_use_value.Slash = 4.6
sgs.ai_keep_value.Slash = 2
sgs.ai_use_priority.Slash = 2.4

function SmartAI:useCardPeach(card, use)
	local mustusepeach = false
	if not self.player:isWounded() then return end
	if self.player:hasSkill("longhun") and not self.player:isLord() and
		math.min(self.player:getMaxCards(), self.player:getHandcardNum()) + self.player:getCards("e"):length() > 3 then return end
	local peaches = 0
	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	for _, card in ipairs(cards) do
		if card:isKindOf("Peach") then peaches = peaches + 1 end
	end
	if self.player:isLord() and (self.player:hasSkill("hunzi") and self.player:getMark("hunzi") == 0)
		and self.player:getHp() < 4 and self.player:getHp() > peaches then return end
	for _, enemy in ipairs(self.enemies) do
		if (self:hasSkills(sgs.drawpeach_skill, enemy) and self.player:getHandcardNum() < 3) then
			mustusepeach = true
		end
	end
	if self.player:hasSkill("rende") and #self.friends_noself > 0 then
		return
	end

	if mustusepeach or (self.player:hasSkill("buqu") and self.player:getHp() < 1) or peaches > self.player:getHp() then
		use.card = card
		return
	end

	if self.player:hasSkill("jiuchi") and self:getCardsNum("Analeptic") > 0 and self:getOverflow() <= 0 and #self.friends_noself > 0 then
		return
	end

	if self.player:getHp() > getBestHp(self.player) then return end

	local lord = self.room:getLord()
	if self:isFriend(lord) and lord:getHp() <= 2 and not lord:hasSkill("buqu") then
		if self.player:isLord() then use.card = card end
		return
	end

	self:sort(self.friends, "hp")
	if self.friends[1]:objectName() == self.player:objectName() or self.player:getHp()<2 then
		use.card = card
		return
	end

	if #self.friends > 1 and self.friends[2]:getHp() < 3 and not self.friends[2]:hasSkill("buqu") and self:getOverflow() < 1 then
		return
	end

	if self.player:hasSkill("jieyin") and self:getOverflow() > 0 then
		self:sort(self.friends, "hp")
		for _, friend in ipairs(self.friends) do
			if friend:isWounded() and friend:isMale() then return end
		end
	end

	if self.player:hasSkill("ganlu") and not self.player:hasUsed("GanluCard") then
		local dummy_use = { isDummy = true }
		self:useSkillCard(sgs.Card_Parse("@GanluCard=."), dummy_use)
		if dummy_use.card then return end
	end

	use.card = card
end

sgs.ai_card_intention.Peach = -120

sgs.ai_use_value.Peach = 6
sgs.ai_keep_value.Peach = 5
sgs.ai_use_priority.Peach = 2.8

sgs.ai_use_value.Jink = 8.9
sgs.ai_keep_value.Jink = 4

sgs.dynamic_value.benefit.Peach = true

sgs.weapon_range.Weapon = 1
sgs.weapon_range.Crossbow = 1
sgs.weapon_range.DoubleSword = 2
sgs.weapon_range.QinggangSword = 2
sgs.weapon_range.IceSword = 2
sgs.weapon_range.GudingBlade = 2
sgs.weapon_range.Axe = 3
sgs.weapon_range.Blade = 3
sgs.weapon_range.Spear = 3
sgs.weapon_range.Halberd = 4
sgs.weapon_range.KylinBow = 5

sgs.ai_skill_invoke.double_sword = true

function sgs.ai_slash_weaponfilter.double_sword(to, self)
	return self.player:getGender()~=to:getGender()
end

function sgs.ai_weapon_value.double_sword(self, enemy)
	if enemy and enemy:isMale() ~= self.player:isMale() then return 3 end
end

sgs.ai_skill_cardask["double-sword-card"] = function(self, data, pattern, target)
	if target and self:isFriend(target) then return "." end
	if self:needBear() then return "." end
	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if card:isKindOf("Slash") or card:isKindOf("Collateral") or card:isKindOf("GodSalvation")
		or card:isKindOf("Disaster") or card:isKindOf("EquipCard") or card:isKindOf("AmazingGrace") then
			return "$" .. card:getEffectiveId()
		end
	end
	return "."
end

function sgs.ai_weapon_value.qinggang_sword(self, enemy)
	if enemy and enemy:getArmor() then return 3 end
end

sgs.ai_skill_invoke.ice_sword = function(self, data)
	local damage = data:toDamage()
	local target = damage.to
	if self:isFriend(target) then
		if self:isWeak(target) or damage.damage > 1 then return true
		elseif target:getLostHp() < 1 then return false end
		return true
	else
		if self:isWeak(target) or damage.damage > 1 then return false end
		if target:getArmor() and self:evaluateArmor(target:getArmor(), target) > 3 then return true end
		local num = target:getHandcardNum()
		if self.player:hasSkill("tieji") or (self.player:hasSkill("liegong")
			and (num >= self.player:getHp() or num <= self.player:getAttackRange())) then return false end
		if target:hasSkill("tuntian") then return false end
		if self:hasSkills(sgs.need_kongcheng, target) then return false end
		if target:getCards("he"):length() < 4 and target:getCards("he"):length() > 1 then return true end
		return false
	end
end

function sgs.ai_slash_weaponfilter.guding_blade(to)
	return to:isKongcheng()
end

function sgs.ai_weapon_value.guding_blade(self, enemy)
	if not enemy then return end
	local value = 2
	if enemy:getHandcardNum() < 1 then value = 4 end
	return value
end

sgs.ai_skill_cardask["@axe"] = function(self, data, pattern, target)
	if target and self:isFriend(target) then return "." end
	local effect = data:toSlashEffect()
	local allcards = self.player:getCards("he")
	allcards = sgs.QList2Table(allcards)
	if effect.slash:hasFlag("drank") or #allcards - 2 >= self.player:getHp()
		or ((self.player:hasSkill("kuanggu") or self:isEquip("SilverLion")) and self.player:isWounded()) then
		local cards = self.player:getCards("h")
		cards = sgs.QList2Table(cards)
		local armor_used = false
		local index
		if self.player:getArmor() and self.player:getArmor():isKindOf("SilverLion") and self.player:isWounded() then
			armor_used = true
		end
		if self:hasSkills(sgs.need_kongcheng) then index = #cards end
		if self.player:getOffensiveHorse() then
			if index then
				if index < 2 then
					index = index + 1
					table.insert(cards, self.player:getOffensiveHorse())
				end
			end
			table.insert(cards, self.player:getOffensiveHorse())
		end
		if self.player:getArmor() and not armor_used then
			if index then
				if index < 2 then
					index = index + 1
					table.insert(cards, self.player:getArmor())
				end
			end
			table.insert(cards, self.player:getArmor())
		end
		if self.player:getDefensiveHorse() then
			if index then
				if index < 2 then
					index = index + 1
					table.insert(cards, self.player:getDefensiveHorse())
				end
			end
			table.insert(cards, self.player:getDefensiveHorse())
		end
		if armor_used and #cards >= 1 then
			self:sortByUseValue(cards, true)
			return "$" .. self.player:getArmor():getEffectiveId() .. "+" .. cards[1]:getEffectiveId()
		elseif #cards >= 2 then
			self:sortByUseValue(cards, true)
			return "$" .. cards[1]:getEffectiveId() .. "+" .. cards[2]:getEffectiveId()
		end
	end
end

function sgs.ai_slash_weaponfilter.axe(to, self)
	return self:getOverflow() > 0
end

function sgs.ai_weapon_value.axe(self, enemy)
	if self:hasSkills("jiushi|jiuchi|luoyi|pojun", self.player) then return 6 end
	if enemy and enemy:getHp() < 3 then return 5 - enemy:getHp() end
end

sgs.ai_skill_cardask["blade-slash"] = function(self, data, pattern, target)
	if target and self:isFriend(target) and not (target:hasSkill("leiji") and getCardsNum("Jink", target) > 0) then
		return "."
	end
	for _, slash in ipairs(self:getCards("Slash")) do
		if self:slashIsEffective(slash, target) then
			return slash:toString()
		end
	end
	return "."
end

function sgs.ai_weapon_value.blade(self, enemy)
	if not enemy then return self:getCardsNum("Slash") end
end

function sgs.ai_cardsview.spear(class_name, player)
	if class_name == "Slash" then
		local cards = player:getCards("he")
		cards = sgs.QList2Table(cards)
		for _, acard in ipairs(cards) do
			if isCard("Slash", acard, player) then return end
		end
		local cards = player:getCards("h")
		cards = sgs.QList2Table(cards)
		local newcards = {}
		for _, card in ipairs(cards) do
			if not card:isKindOf("Peach") and not (card:isKindOf("ExNihilo") and player:getPhase() == sgs.Player_Play) then table.insert(newcards, card) end
		end
		if #newcards <= player:getHp() - 1 and not player:hasSkill("paoxiao") then return end
		if #newcards < 2 then return end

		local card_id1 = newcards[1]:getEffectiveId()
		local card_id2 = newcards[2]:getEffectiveId()

		local card_str = ("slash:spear[%s:%s]=%d+%d"):format("to_be_decided", 0, card_id1, card_id2)
		return card_str
	end
end

local spear_skill = {}
spear_skill.name = "spear"
table.insert(sgs.ai_skills, spear_skill)
spear_skill.getTurnUseCard = function(self, inclusive)
	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)

	self:sortByUseValue(cards)

	local newcards = {}
	for _, acard in ipairs(cards) do
		if isCard("Slash", acard, self.player) then return end
	end
	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)
	local newcards = {}
	for _, card in ipairs(cards) do
		if not card:isKindOf("Peach") and not (card:isKindOf("ExNihilo") and self.player:getPhase() == sgs.Player_Play) then table.insert(newcards, card) end
	end
	if #newcards <= self.player:getHp() - 1 and not self.player:hasSkill("paoxiao") then return end
	if #newcards < 2 then return end

	local card_id1 = newcards[1]:getEffectiveId()
	local card_id2 = newcards[2]:getEffectiveId()

	local card_str = ("slash:spear[%s:%s]=%d+%d"):format("to_be_decided", 0, card_id1, card_id2)
	local slash = sgs.Card_Parse(card_str)
	return slash
end

function sgs.ai_slash_weaponfilter.fan(to)
	local armor = to:getArmor()
	return armor and armor:isKindOf("Vine")
end

sgs.ai_skill_invoke.kylin_bow = function(self, data)
	local damage = data:toDamage()

	if self:hasSkills(sgs.lose_equip_skill, damage.to) then
		return self:isFriend(damage.to)
	end

	return self:isEnemy(damage.to)
end

function sgs.ai_slash_weaponfilter.kylin_bow(to)
	if to:getDefensiveHorse() then return true else return false end
end

function sgs.ai_weapon_value.kylin_bow(self, target)
	if not target then
		for _, enemy in ipairs(self.enemies) do
			if enemy:getOffensiveHorse() or enemy:getDefensiveHorse() then return 1 end
		end
	end
end

sgs.ai_skill_invoke.eight_diagram = function(self, data)
	local dying = 0
	local handang = self.room:findPlayerBySkillName("nosjiefan")
	for _, aplayer in sgs.qlist(self.room:getAlivePlayers()) do
		if aplayer:getHp() < 1 and not aplayer:hasSkill("buqu") then dying = 1 break end
	end
	if handang and self:isFriend(handang) and dying > 0 then return false end
	if self.player:hasFlag("dahe") then return false end
	if sgs.hujiasource and not self:isFriend(sgs.hujiasource) then return false end
	if self.player:hasSkill("tiandu") then return true end
	if self:hasSkills("guidao", self.enemies) and self:getFinalRetrial(sgs.hujiasource) == 2 then
		return false
	end
	if self:getDamagedEffects(self.player) or self.player:getHp()>getBestHp(self.player) then return false end
	return true
end

function sgs.ai_armor_value.eight_diagram(player, self)
	local haszj = self:hasSkills("guidao", self:getEnemies(player))
	if haszj then
		return 2
	end
	if player:hasSkill("tiandu") then
		return 6
	end

	if self.role == "loyalist" and self.player:getKingdom() == "wei" and not self:hasSkills("bazhen|yizhong") and self.room:getLord():hasLordSkill("hujia") then
		return 5
	end

	return 4
end

function sgs.ai_armor_value.renwang_shield()
	return 4.5
end

function sgs.ai_armor_value.silver_lion(player, self)
	if self:hasWizard(self:getEnemies(player), true) then
		for _, player in sgs.qlist(self.room:getAlivePlayers()) do
			if player:containsTrick("lightning") then return 5 end
		end
	end
	return 1
end

sgs.ai_use_priority.OffensiveHorse = 2.69
sgs.ai_use_priority.Halberd = 2.685
sgs.ai_use_priority.KylinBow = 2.68
sgs.ai_use_priority.Blade = 2.675
sgs.ai_use_priority.GudingBlade = 2.67
sgs.ai_use_priority.DoubleSword  = 2.665
sgs.ai_use_priority.Spear = 2.66
sgs.ai_use_priority.IceSword = 2.65
sgs.ai_use_priority.QinggangSword = 2.645
sgs.ai_use_priority.Axe = 2.64
sgs.ai_use_priority.Crossbow = 2.63
sgs.ai_use_priority.SilverLion = 0.9
sgs.ai_use_priority.EightDiagram = 0.8
sgs.ai_use_priority.RenwangShield = 0.7
sgs.ai_use_priority.DefensiveHorse = 2.75

sgs.dynamic_value.damage_card.ArcheryAttack = true
sgs.dynamic_value.damage_card.SavageAssault = true

sgs.ai_use_value.ArcheryAttack = 3.8
sgs.ai_use_priority.ArcheryAttack = 3.5
sgs.ai_use_value.SavageAssault = 3.9
sgs.ai_use_priority.SavageAssault = 3.5

sgs.ai_skill_cardask.aoe = function(self, data, pattern, target, name)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if not self:damageIsEffective(nil, nil, target) then return "." end
	if target:hasSkill("drwushuang") and self.player:getCardCount(true) == 1 then return "." end

	local aoe = sgs.Sanguosha:cloneCard(name, sgs.Card_NoSuit, 0)
	local menghuo = self.room:findPlayerBySkillName("huoshou")
	local attacker = target
	if menghuo and aoe:isKindOf("SavageAssault") then attacker = menghuo end

	if self:getDamagedEffects(self.player, attacker) or self.player:getHp() > getBestHp(self.player) then return "." end

	if self.player:hasSkill("wuyan") and not target:hasSkill("jueqing") then return "." end
	if target:hasSkill("wuyan") and not target:hasSkill("jueqing") then return "." end
	if self.player:getMark("@fenyong") > 0 and not target:hasSkill("jueqing") then return "." end

	if self.player:hasSkill("jianxiong") and self:getAoeValue(aoe) > -10 and
		(self.player:getHp() > 1 or self:getAllPeachNum() > 0) and not self.player:containsTrick("indulgence") then return "." end
end

sgs.ai_skill_cardask["savage-assault-slash"] = function(self, data, pattern, target)
	return sgs.ai_skill_cardask.aoe(self, data, pattern, target, "savage_assault")
end

sgs.ai_skill_cardask["archery-attack-jink"] = function(self, data, pattern, target)
	return sgs.ai_skill_cardask.aoe(self, data, pattern, target, "archery_attack")
end

sgs.ai_keep_value.Nullification = 3
sgs.ai_use_value.Nullification = 8

function SmartAI:useCardAmazingGrace(card, use)
	if self.player:hasSkill("noswuyan") then use.card = card end
	if self.player:getRole() == "loyalist" and self.player:getSeat() == 2 and sgs.turncount == 1 or self.player:getRole() == "lord" and sgs.turncount == 0 then return end
	local value = 1
	local suf, coeff = 0.8, 0.8
	if self:hasSkills(sgs.need_kongcheng) and self.player:getHandcardNum() == 1 or self.player:hasSkill("jizhi") then
		suf = 0.6
		coeff = 0.6
	end
	for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		local index = 0
		if self:isFriend(player) then index = 1 elseif self:isEnemy(player) then index = -1 end
		value = value + index * suf
		if value < 0 then return end
		suf = suf * coeff
	end
	use.card = card
end

sgs.ai_use_value.AmazingGrace = 3
sgs.ai_keep_value.AmazingGrace = -1
sgs.ai_use_priority.AmazingGrace = 1

function SmartAI:useCardGodSalvation(card, use)
	local good, bad = 0, 0
	if self.player:hasSkill("noswuyan") and self.player:isWounded() then
		use.card = card
		return
	end

	for _, friend in ipairs(self.friends) do
		if friend:isWounded() then
			good = good + 10/(friend:getHp())
			if friend:isLord() then good = good + 10/(friend:getHp()) end
		end
	end

	for _, enemy in ipairs(self.enemies) do
		if enemy:isWounded() then
			bad = bad + 10/(enemy:getHp())
			if enemy:isLord() then
				bad = bad + 10/(enemy:getHp())
			end
		end
	end

	if good > bad then
		use.card = card
	end
end

sgs.ai_use_priority.GodSalvation = 3.9
sgs.dynamic_value.benefit.GodSalvation = true

function SmartAI:useCardDuel(duel, use)
	if self.player:hasSkill("wuyan") then return end
	if self.player:hasSkill("noswuyan") then return end
	self:sort(self.enemies,"defense")
	local enemies = self:exclude(self.enemies, duel)
	local friends = self:exclude(self.friends_noself, duel)
	local n1 = self:getCardsNum("Slash")
	local huatuo = self.room:findPlayerBySkillName("jijiu")

	local canUseDuelTo = function(target)
		return self:hasTrickEffective(duel, target) and (self:damageIsEffective(target, sgs.DamageStruct_Normal) or self.player:hasSkill("jueqing"))
				and not self.room:isProhibited(self.player, target, duel)
	end

	for _, friend in ipairs(friends) do
		if friend:hasSkill("jieming") and canUseDuelTo(friend) and self.player:hasSkill("rende") and (huatuo and self:isFriend(huatuo))then
			use.card = duel
			if use.to then
				use.to:append(friend)
			end
			return
		end
	end

	for _, enemy in ipairs(enemies) do
		local useduel 
		local n2 = getCardsNum("Slash", enemy)
		if sgs.card_lack[enemy:objectName()]["Slash"] == 1 then n2 = 0 end
		useduel = n1 >= n2 or self.player:getHp() > getBestHp(self.player) or self:getDamagedEffects(self.player, enemy) or (n2 < 1 and sgs.isGoodHp(self.player))
		useduel = useduel and enemy:getHp() <= getBestHp(enemy) and not self:getDamagedEffects(enemy, self.player)
		useduel = useduel and not (enemy:hasSkill("jianxiong") and not self:isWeak(enemy) and not self.player:hasSkill("jueqing"))
		if self:objectiveLevel(enemy) > 3 and canUseDuelTo(enemy) and not self:cantbeHurt(enemy) and sgs.isGoodTarget(enemy, self.enemies) and useduel then
			use.card = duel
			if use.to then
				use.to:append(enemy)
				self:speak("duel", self.player:isFemale())
			end
			return
		end
	end

end

sgs.ai_card_intention.Duel = function(self, card, from, tos)
	if sgs.ai_lijian_effect then
		sgs.ai_lijian_effect = false
		return
	end
	sgs.updateIntentions(from, tos, 80)
end

sgs.ai_use_value.Duel = 3.7
sgs.ai_use_priority.Duel = 2.9

sgs.dynamic_value.damage_card.Duel = true

sgs.ai_skill_cardask["duel-slash"] = function(self, data, pattern, target)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if self.player:hasSkill("wuyan") and not target:hasSkill("jueqing") then return "." end
	if target:hasSkill("wuyan") and not self.player:hasSkill("jueqing") then return "." end
	if self:getDamagedEffects(self.player, target) or self.player:getHp()>getBestHp(self.player) then return "." end
	if self:isFriend(target) and target:hasSkill("rende") and self.player:hasSkill("jieming") then return "." end
	if self.player:getMark("@fenyong") > 0 and not target:hasSkill("jueqing") then return "." end
	if (not self:isFriend(target) and self:getCardsNum("Slash")* 2 >= target:getHandcardNum())
		or (target:getHp() > 2 and self.player:getHp() <= 1 and self:getCardsNum("Peach") == 0 and not self.player:hasSkill("buqu")) then
		return self:getCardId("Slash")
	else return "." end
end

function SmartAI:useCardExNihilo(card, use)
	use.card = card
	if not use.isDummy then
		self:speak("lucky")
	end
end

sgs.ai_card_intention.ExNihilo = -80

sgs.ai_keep_value.ExNihilo = 3.6
sgs.ai_use_value.ExNihilo = 10
sgs.ai_use_priority.ExNihilo = 9.3

sgs.dynamic_value.benefit.ExNihilo = true

function SmartAI:getDangerousCard(who)
	local weapon = who:getWeapon()
	local armor = who:getArmor()
	if weapon and weapon:isKindOf("Spear") and who:getHandcardNum() >= 3 and who:hasSkill("paoxiao") then return weapon:getEffectiveId() end
	if weapon and weapon:isKindOf("Axe") and self:hasSkills("luoyi|pojun|jiushi|jiuchi", who) then return weapon:getEffectiveId() end
	if armor and who:getArmor():isKindOf("EightDiagram") and who:getArmor():getSuit() == sgs.Card_Spade and who:hasSkill("leiji") then return who:getArmor():getEffectiveId() end
	if weapon and (weapon:isKindOf("SPMoonSpear") or weapon:isKindOf("MoonSpear")) and self:hasSkills("guidao|chongzhen|guicai|jilve", who) then return weapon:getEffectiveId() end
	if weapon and who:hasSkill("liegong") and sgs.weapon_range[weapon:getClassName()] >= who:getHp() - 1 then return weapon:getEffectiveId() end
	if weapon and weapon:isKindOf("Crossbow") and getCardsNum("Slash", who) > 1 then return weapon:getEffectiveId() end
end

function SmartAI:getValuableCard(who)
	local weapon = who:getWeapon()
	local armor = who:getArmor()
	local offhorse = who:getOffensiveHorse()
	local defhorse = who:getDefensiveHorse()
	self:sort(self.friends, "hp")
	local friend
	if #self.friends > 0 then friend = self.friends[1] end
	if friend and self:isWeak(friend) and who:distanceTo(friend) <= who:getAttackRange() and not who:hasSkill("nosxuanfeng") then
		if weapon and who:distanceTo(friend) > 1 and not
			(weapon and (weapon:isKindOf("MoonSpear") or weapon:isKindOf("SPMoonSpear")) and who:hasSkill("keji") and who:getHandcardNum() > 5) then return weapon:getEffectiveId() end
		if offhorse and who:distanceTo(friend) > 1 then return offhorse:getEffectiveId() end
	end

	if defhorse and not who:hasSkill("nosxuanfeng") then
		for _, friend in ipairs(self.friends) do
			if friend:distanceTo(who) == friend:getAttackRange() + 1 then
				return defhorse:getEffectiveId()
			end
		end
	end

	if armor and self:evaluateArmor(armor, who) > 3 and not who:hasSkill("nosxuanfeng") then
		return armor:getEffectiveId()
	end

	local equips = sgs.QList2Table(who:getEquips())
	for _, equip in ipairs(equips) do
		if who:hasSkill("shensu") then return equip:getEffectiveId() end
		if who:hasSkill("longhun") and not equip:getSuit() == sgs.Card_Diamond then return equip:getEffectiveId() end
		if who:hasSkill("qixi") and equip:isBlack() then return equip:getEffectiveId() end
		if who:hasSkill("guidao") and equip:isBlack() then return equip:getEffectiveId() end
		if who:hasSkill("guose") and equip:getSuit() == sgs.Card_Diamond then return equip:getEffectiveId() end
		if who:hasSkill("jijiu") and equip:isRed() then return equip:getEffectiveId() end
		if who:hasSkill("wusheng") and equip:isRed() then return equip:getEffectiveId() end
		if who:hasSkill("duanliang") and equip:isBlack() then return equip:getEffectiveId() end
	end

	if armor and self:evaluateArmor(armor, who) > 0
		and not (armor:isKindOf("SilverLion") and who:isWounded()) then
		return armor:getEffectiveId()
	end

	if weapon then
		if not self:hasSkills(sgs.lose_equip_skill, who) then
			for _, friend in ipairs(self.friends) do
				if ((who:distanceTo(friend) <= who:getAttackRange()) and (who:distanceTo(friend) > 1)) or who:hasSkill("qiangxi") then
					return weapon:getEffectiveId()
				end
			end
		end
	end

	if offhorse then
		if self:hasSkills(sgs.lose_equip_skill, who) then
		else
			for _, friend in ipairs(self.friends) do
				if who:distanceTo(friend) == who:getAttackRange() and
				who:getAttackRange() > 1 then
					return offhorse:getEffectiveId()
				end
			end
		end
	end
end

function SmartAI:useCardSnatchOrDismantlement(card, use)
	local name = card:objectName()
	if self.player:hasSkill("noswuyan") then return end
	local players = self.room:getOtherPlayers(self.player)
	local isJixi = self.player:hasFlag("JixiSnatch")
	local tricks
	players = self:exclude(players, card)
	for _, player in ipairs(players) do
		if (player:containsTrick("lightning") and self:getFinalRetrial(player) == 2 and self:hasTrickEffective(card, player)) or #self.enemies == 0 then
			use.card = card
			if use.to then
				tricks = player:getCards("j")
				for _, trick in sgs.qlist(tricks) do
					if trick:isKindOf("Lightning") then
						sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
					end
				end
				use.to:append(player)
			elseif isJixi then
				self.room:setPlayerFlag(player, "JixiTarget")
			end
			return
		end
	end

	self:sort(self.enemies, "defense")
	local enemies = {}
	if #self.enemies == 0 then
		for _, player in ipairs(players) do
			if not player:isLord() then table.insert(enemies, player) end
		end
		enemies = self:exclude(enemies, card)
	else
		enemies = self:exclude(self.enemies, card)
	end
	self:sort(self.friends_noself, "defense")
	local friends = self:exclude(self.friends_noself, card)
	local hasLion, target
	for _, enemy in ipairs(enemies) do
		if not enemy:isNude() and self:hasTrickEffective(card, enemy) then
			if self:getDangerousCard(enemy) then
				use.card = card
				if use.to then
					sgs.ai_skill_cardchosen[name] = self:getDangerousCard(enemy)
					use.to:append(enemy)
					self:speak("hostile", self.player:isFemale())
				elseif isJixi then
					self.room:setPlayerFlag(enemy, "JixiTarget")
				end
				return
			end
		end
	end

	for _, friend in ipairs(friends) do
		if (friend:containsTrick("indulgence") or friend:containsTrick("supply_shortage")) and not friend:containsTrick("YanxiaoCard")
			and self:hasTrickEffective(card, friend) then
			use.card = card
			if use.to then
				tricks = friend:getJudgingArea()
				for _, trick in sgs.qlist(tricks) do
					if trick:isKindOf("Indulgence") then
						if friend:getHp() <= friend:getHandcardNum() or friend:isLord() or name == "snatch" then
							sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
							break
						end
					end
					if trick:isKindOf("SupplyShortage") then
						sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
						break
					end
					if trick:isKindOf("Indulgence") then
						sgs.ai_skill_cardchosen[name] = trick:getEffectiveId()
						break
					end
				end
				use.to:append(friend)
			elseif isJixi then
				self.room:setPlayerFlag(friend, "JixiTarget")
			end

			return
		end
		if self:isEquip("SilverLion", friend) and self:hasTrickEffective(card, friend) and
			friend:isWounded() and not self:hasSkills(sgs.use_lion_skill, friend) then
			hasLion = true
			target = friend
		end
	end

	for _, enemy in ipairs(enemies) do
		if not enemy:isNude() and self:hasTrickEffective(card, enemy) then
			if self:getValuableCard(enemy) then
				use.card = card
				if use.to then
					sgs.ai_skill_cardchosen[name] = self:getValuableCard(enemy)
					use.to:append(enemy)
					self:speak("hostile", self.player:isFemale())
				elseif isJixi then
					self.room:setPlayerFlag(enemy, "JixiTarget")
				end
				return
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		local cards = sgs.QList2Table(enemy:getHandcards())
		local flag = string.format("%s_%s_%s","visible", self.player:objectName(), enemy:objectName())
		if #cards <= 2 and self:hasTrickEffective(card, enemy) and not enemy:isKongcheng() then
			for _, cc in ipairs(cards) do
				if (cc:hasFlag("visible") or cc:hasFlag(flag)) and (cc:isKindOf("Peach") or cc:isKindOf("Analeptic")) then
					use.card = card
					if use.to then
						sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "h")
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					elseif isJixi then
						self.room:setPlayerFlag(enemy, "JixiTarget")
					end
					return
				end
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		if not enemy:isNude() and self:hasTrickEffective(card, enemy) then
			if self:hasSkills("jijiu|qingnang|jieyin", enemy) then
				local cardchosen
				local equips = { enemy:getDefensiveHorse(), enemy:getArmor(), enemy:getOffensiveHorse(), enemy:getWeapon() }
				for _ , equip in ipairs(equips) do
					if equip and equip:isRed() and enemy:hasSkill("jijiu") then 
						cardchosen = equip:getEffectiveId()
						break
					end
				end

				if not cardchosen and enemy:getDefensiveHorse() then cardchosen = enemy:getDefensiveHorse():getEffectiveId() end
				if not cardchosen and enemy:getArmor() and not enemy:getArmor():isKindOf("SilverLion") then 
					cardchosen = enemy:getArmor():getEffectiveId() 
				end        
				if not cardchosen and not enemy:isKongcheng() and enemy:getHandcardNum() <= 3 then 
					cardchosen = self:getCardRandomly(enemy, "h") 
				end
				
				if cardchosen then        
					use.card = card
					if use.to then
						sgs.ai_skill_cardchosen[name] = cardchosen
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					elseif isJixi then
						self.room:setPlayerFlag(enemy, "JixiTarget")
					end
					return
				end
			end
		end
	end

	for i = 1, 2 + (isJixi and 3 or 0), 1 do
		for _, enemy in ipairs(enemies) do
			if not enemy:isNude() and self:hasTrickEffective(card, enemy)
				and not self:needKongcheng(enemy) and self:hasLoseHandcardEffective(enemy) and i <= 2 then
				if (enemy:getHandcardNum() == i and sgs.getDefenseSlash(enemy) < 6 + (isJixi and 6 or 0) and enemy:getHp() <= 3 + (isJixi and 2 or 0)) then
					local cardchosen
					if self.player:distanceTo(enemy) == self.player:getAttackRange() + 1 and enemy:getDefensiveHorse() then
						cardchosen = enemy:getDefensiveHorse():getEffectiveId()
					elseif enemy:getArmor() and not enemy:getArmor():isKindOf("SilverLion") then
						cardchosen = enemy:getArmor():getEffectiveId()
					else
						cardchosen = self:getCardRandomly(enemy, "h")
					end
					use.card = card
					if use.to then
						sgs.ai_skill_cardchosen[name] = cardchosen
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					elseif isJixi then
						self.room:setPlayerFlag(enemy, "JixiTarget")
					end
					return
				end
			end
		end
	end

	if hasLion then
		use.card = card
		if use.to then
			sgs.ai_skill_cardchosen[name] = target:getArmor():getEffectiveId()
			use.to:append(target)
		elseif isJixi then
			self.room:setPlayerFlag(target, "JixiTarget")
		end
		return
	end

	if name == "snatch" or self:getOverflow() > 0 then
		for _, enemy in ipairs(enemies) do
			local equips = enemy:getEquips()
			if not enemy:isNude() and self:hasTrickEffective(card, enemy) and not enemy:hasSkill("tuntian") and
				not (self:hasSkills(sgs.lose_equip_skill, enemy) and enemy:isKongcheng()) then
				if enemy:getHandcardNum() == 1 then
					if self:needKongcheng(enemy) or not self:hasLoseHandcardEffective(enemy) then return end
				end
				if self:hasSkills(sgs.cardneed_skill, enemy) then
					use.card = card
					if use.to then
						sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "he")
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					elseif isJixi then
						self.room:setPlayerFlag(enemy, "JixiTarget")
					end
					return
				else
					use.card = card
					if use.to then
						if not equips:isEmpty() then
							sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "e")
						else
							sgs.ai_skill_cardchosen[name] = self:getCardRandomly(enemy, "h") end
						use.to:append(enemy)
						self:speak("hostile", self.player:isFemale())
					elseif isJixi then
						self.room:setPlayerFlag(enemy, "JixiTarget")
					end
					return
				end
			end
		end
	end
end

SmartAI.useCardSnatch = SmartAI.useCardSnatchOrDismantlement

sgs.ai_use_value.Snatch = 9
sgs.ai_use_priority.Snatch = 4.3

sgs.dynamic_value.control_card.Snatch = true
function sgs.ai_card_intention.Snatch()
	sgs.ai_snat_disma_effect = false
end

SmartAI.useCardDismantlement = SmartAI.useCardSnatchOrDismantlement

sgs.ai_use_value.Dismantlement = 5.6
sgs.ai_use_priority.Dismantlement = 4.4
function sgs.ai_card_intention.Dismantlement()
	sgs.ai_snat_disma_effect = false
end

sgs.dynamic_value.control_card.Dismantlement = true

function SmartAI:useCardCollateral(card, use)
	if self.player:hasSkill("noswuyan") then return end
	self:sort(self.enemies,"threat")

	for _, friend in ipairs(self.friends_noself) do
		if friend:getWeapon() and self:hasSkills(sgs.lose_equip_skill, friend)
			and not friend:hasSkill("weimu")
			and not self.room:isProhibited(self.player, friend, card) then

			for _, enemy in ipairs(self.enemies) do
				if friend:canSlash(enemy, nil) then
					use.card = card
				end
				if use.to then use.to:append(friend) end
				if use.to then use.to:append(enemy) end
				return
			end
		end
	end

	local n = nil
	local final_enemy = nil
	for _, enemy in ipairs(self.enemies) do
		if not self.room:isProhibited(self.player, enemy, card)
			and self:hasTrickEffective(card, enemy)
			and not self:hasSkills(sgs.lose_equip_skill, enemy)
			and not enemy:hasSkill("weimu")
			and enemy:getWeapon() then

			for _, enemy2 in ipairs(self.enemies) do
				if enemy:canSlash(enemy2, card) then
					if enemy:getHandcardNum() == 0 then
						use.card = card
						if use.to then use.to:append(enemy) end
						if use.to then use.to:append(enemy2) end
						return
					else
						n = 1;
						final_enemy = enemy2
					end
				end
			end
			if n then use.card = card end
			if use.to then use.to:append(enemy) end
			if use.to then use.to:append(final_enemy) end
			return

		end
		n = nil
	end
end

sgs.ai_use_value.Collateral = 5.8
sgs.ai_use_priority.Collateral = 2.75

sgs.ai_card_intention.Collateral = function(self, card, from, tos)
	assert(#tos == 1)
	if sgs.compareRoleEvaluation(tos[1], "rebel", "loyalist") ~= sgs.compareRoleEvaluation(from, "rebel", "loyalist") then
		sgs.updateIntention(from, tos[1], 80)
	end
	sgs.ai_collateral = false
end

sgs.dynamic_value.control_card.Collateral = true

sgs.ai_skill_cardask["collateral-slash"] = function(self, data, pattern, target, target2)
	if self:isFriend(target2) and target2:hasSkill("leiji") 
		and (self:hasSuit("spade", true, target2) or target2:getHandcardNum() >= 3)
		and (getKnownCard(target2, "Jink", true) >= 1
		or (not self:isWeak(friend) and not self:isEquip("QinggangSword", self.player) and self:isEquip("EightDiagram", friend))) then
		for _, slash in ipairs(self:getCards("Slash")) do
			if self:slashIsEffective(slash, target2) then 
				return slash:toString()
			end
		end
	end
	if target and target2 and (self.getDamagedEffects(target2, self.player) or target2:getHp() > getBestHp(target2)) then   
		for _, slash in ipairs(self:getCards("Slash")) do
			if self:slashIsEffective(slash, target2) and self:isFriend(target2) then
				return slash:toString()
			end
			if not self:slashIsEffective(slash, target2) and self:isEnemy(target2) then
				return slash:toString()
			end
		end
		for _, slash in ipairs(self:getCards("Slash")) do
			if not self.getDamagedEffects(target2, self.player) and self:isEnemy(target2) then 
				return slash:toString()
			end
		end
	end

	if self:needBear() then return "." end
	if target and target2 and not self:hasSkills(sgs.lose_equip_skill) and self:isEnemy(target2) then
		for _, slash in ipairs(self:getCards("Slash")) do
			if self:slashIsEffective(slash, target2) then
				return slash:toString()
			end
		end
	end
	if target and target2 and not self:hasSkills(sgs.lose_equip_skill) and self:isFriend(target2) then
		for _, slash in ipairs(self:getCards("Slash")) do
			if not self:slashIsEffective(slash, target2) then
				return slash:toString()
			end
		end
		if (target2:getHp() > 2 or getCardsNum("Jink", target2) > 1) and not target2:getRole() == "lord" and self.player:getHandcardNum() > 1 then
			for _, slash in ipairs(self:getCards("Slash")) do
				return slash:toString()
			end
		end
	end
	self:speak("collateral", self.player:isFemale())
	return "."
end

local function hp_subtract_handcard(a, b)
	local diff1 = a:getHp() - a:getHandcardNum()
	local diff2 = b:getHp() - b:getHandcardNum()

	return diff1 < diff2
end

function SmartAI:useCardIndulgence(card, use)
	local enemies = {}
	if #self.enemies == 0 then
		if sgs.turncount == 0 and self.role == "lord" and not sgs.isRolePredictable() 
			and sgs.role_evaluation[self.player:getNextAlive():objectName()]["loyalist"] == 30 then
			enemies = self:exclude({ self.player:getNextAlive() }, card)
		end
	else
		enemies = self:exclude(self.enemies, card)
	end

	local zhanghe = self.room:findPlayerBySkillName("qiaobian")
	local zhanghe_seat = zhanghe and zhanghe:faceUp() and self:isEnemy(zhanghe) and zhanghe:getSeat() or 0

	if #enemies == 0 then return end

	local getvalue = function(enemy)
		if enemy:containsTrick("indulgence") or enemy:containsTrick("YanxiaoCard") or self:hasSkills("qiaobian", enemy) then return -100 end
		if zhanghe_seat > 0 then
			local gap1 = (enemy:getSeat() - self.player:getSeat()) % self.room:alivePlayerCount()
			local gap2 = (zhanghe_seat - self.player:getSeat()) % self.room:alivePlayerCount()
			if gap1 >= gap2 then return -100 end
		end

		local value = enemy:getHandcardNum() - enemy:getHp()

		if self:hasSkills("lijian|fanjian|neofanjian|dimeng|jijiu|jieyin", enemy) then value = value + 10 end
		if self:isWeak(enemy) then value = value + 3 end
		if enemy:isLord() then value = value + 3 end

		if self:objectiveLevel(enemy)<3 then value = value -10 end
		if not enemy:faceUp() then value = value -10 end
		if self:hasSkills("keji|shensu", enemy) then value = value - enemy:getHandcardNum() end
		if self:hasSkills("guanxing|xiuluo", enemy) then value = value - 5 end
		if not sgs.isGoodTarget(enemy) then value = value - 1 end
		return value
	end

	local cmp = function(a, b)
		return getvalue(a) > getvalue(b)
	end

	table.sort(enemies, cmp)

	local target=enemies[1]
	if getvalue(target) > -100 then
		use.card = card
		if use.to then use.to:append(target) end
		return
	end
end

sgs.ai_use_value.Indulgence = 8
sgs.ai_use_priority.Indulgence = 0.5
sgs.ai_card_intention.Indulgence = 120

sgs.dynamic_value.control_usecard.Indulgence = true

function SmartAI:useCardLightning(card, use)
	if self.player:containsTrick("lightning") then return end
	if self.player:hasSkill("weimu") and card:isBlack() then return end
	if self.room:isProhibited(self.player, self.player, card) then end

	--if not self:hasWizard(self.enemies) then--and self.room:isProhibited(self.player, self.player, card) then
	local function hasDangerousFriend()
		local hashy = false
		for _, aplayer in ipairs(self.enemies) do
			if aplayer:hasSkill("hongyan") then hashy = true break end
		end
		for _, aplayer in ipairs(self.enemies) do
			if aplayer:hasSkill("guanxing") or (aplayer:hasSkill("gongxin") and hashy)
			or aplayer:hasSkill("xinzhan") then
				if self:isFriend(aplayer:getNextAlive()) then return true end
			end
		end
		return false
	end
	if self:getFinalRetrial(self.player) == 2 then
	return
	elseif self:getFinalRetrial(self.player) == 1 then
		use.card = card
		return
	elseif not hasDangerousFriend() then
		local players = self.room:getAllPlayers()
		players = sgs.QList2Table(players)

		local friends = 0
		local enemies = 0

		for _, player in ipairs(players) do
			if self:objectiveLevel(player) >= 4 then
				enemies = enemies + 1
			elseif self:isFriend(player) then
				friends = friends + 1
			end
		end

		local ratio
		if friends == 0 then ratio = 999 else ratio = enemies / friends end

		if ratio > 1.5 then
			use.card = card
			return
		end
	end
end

sgs.dynamic_value.lucky_chance.Lightning = true

sgs.ai_keep_value.Lightning = -1

sgs.ai_skill_askforag.amazing_grace = function(self, card_ids)
	local wuguotai = self.room:findPlayerBySkillName(wuguotai)
	
	local cards = {}
	for _, id in ipairs(card_ids) do
		table.insert(cards, sgs.Sanguosha:getCard(id))
	end
	local next_alive = self.player:getNextAlive()
	if next_alive:getPhase() == sgs.Player_Play then
		self:sortByCardNeed(cards, true)
		return cards[1]:getEffectiveId()
	end
	local no_basic_num = 0
	for _, c in ipairs(cards) do
		if c:getTypeId() ~= sgs.Card_TypeBasic then no_basic_num = no_basic_num + 1 end
	end
	local next_need_buyi = false
	if not next_alive:hasSkill("manjuan") and wuguotai and self:isFriend(next_alive, wuguotai) and self:isWeak(next_alive) then next_need_buyi = true end
	if self.player:hasSkill("manjuan") and self.player:getPhase() == sgs.Player_NotActive then
		if self:isFriend(next_alive) then
			self:sortByCardNeed(cards)
			local index = 1
			if next_need_buyi and no_basic_num == 1 then index = 2 end
			return cards[index]:getEffectiveId()
		elseif self:isEnemy(next_alive) then
			self:sortByCardNeed(cards, true)
			if next_need_buyi and no_basic_num == 1 then
				for _, c in ipairs(cards) do
					if c:getTypeId() ~= sgs.Card_TypeBasic then return c:getEffectiveId() end
				end
			end
			return cards[1]:getEffectiveId()
		end
	end
	if self.player:hasSkill("kongcheng") and self.player:isKongcheng() 
		and not self.player:hasSkill("manjuan") and self.player:getPhase() == sgs.Player_NotActive then
		for _, c in ipairs(cards) do
			if c:isKindOf("Jink") or c:isKindOf("Peach") then return c:getEffectiveId() end
		end
	end
	self:sortByCardNeed(cards, true)
	return cards[1]:getEffectiveId()
end
