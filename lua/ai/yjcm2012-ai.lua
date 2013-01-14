sgs.ai_skill_invoke.zishou = function(self, data)
	local chance_value = 1
	if (self.player:getHp() <= 2) then chance_value = chance_value + 1 end

	local peach_num = self:getCardsNum("Peach")
	local can_save_card_num = self.player:getMaxCards() - self.player:getHandcardNum()

	return self.player:isSkipped(sgs.Player_Play)
			or ((self.player:getLostHp() + 2) - can_save_card_num + peach_num <= chance_value)
end

sgs.ai_skill_invoke.qianxi = function(self, data)
	local damage = data:toDamage()
	local target = damage.to
	if self:isFriend(target) then return false end
	if target:getLostHp() >= 2 and target:getHp() <= 1 then return false end
	if self:hasSkills(sgs.masochism_skill, target) or self:hasSkills(sgs.recover_skill, target) or self:hasSkills("longhun|buqu", target) then return true end
	if damage.damage > 1 then return false end
	return (target:getMaxHp() - target:getHp()) < 2
end

sgs.ai_skill_invoke.fuli = true

sgs.ai_skill_invoke.fuhun = function(self, data)
	local target = 0
	for _, enemy in ipairs(self.enemies) do
		if (self.player:distanceTo(enemy) <= self.player:getAttackRange()) then target = target + 1 end
	end
	return target > 0 and not self.player:isSkipped(sgs.Player_Play)
end

sgs.ai_skill_invoke.zhenlie = function(self, data)
	local judge = data:toJudge()
	if not judge:isGood() then
	return true end
	return false
end

sgs.ai_skill_playerchosen.miji = function(self, targets)
	targets = sgs.QList2Table(targets)
	self:sort(targets, "defense")
	for _, target in ipairs(targets) do
		if self:isFriend(target) then return target end
	end
end

sgs.ai_skill_choice.jiangchi = function(self, choices)
	local target = 0
	local goodtarget = 0
	local slashnum = 0
	local needburst = 0

	for _, slash in ipairs(self:getCards("Slash")) do
		for _, enemy in ipairs(self.enemies) do
			if self:slashIsEffective(slash, enemy) then
				slashnum = slashnum + 1 break
			end
		end
	end

	for _, enemy in ipairs(self.enemies) do
		for _, slash in ipairs(self:getCards("Slash")) do
			if self:slashIsEffective(slash, enemy) and (self.player:distanceTo(enemy) <= self.player:getAttackRange()) then
				goodtarget = goodtarget + 1
				break
			end
		end
	end
	if slashnum > 1 or (slashnum > 0 and goodtarget == 0) then needburst = 1 end
	self:sort(self.enemies,"defenseSlash")
	if goodtarget == 0 or self.player:isSkipped(sgs.Player_Play) then return "jiang" end

	for _, enemy in ipairs(self.enemies) do
		local def = sgs.getDefense(enemy)
		local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuitNoColor, 0)
		local eff = self:slashIsEffective(slash, enemy) and sgs.isGoodTarget(enemy, self.enemies)

		if not self.player:canSlash(enemy, nil, false) then
		elseif self:slashProhibit(nil, enemy) then
		elseif def < 6 and eff and needburst > 0 then return "chi"
		end
	end

	for _, enemy in ipairs(self.enemies) do
		local def = sgs.getDefense(enemy)
		local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuitNoColor, 0)
		local eff = self:slashIsEffective(slash, enemy) and sgs.isGoodTarget(enemy, self.enemies)

		if not self.player:canSlash(enemy, nil, false) then
		elseif self:slashProhibit(nil, enemy) then
		elseif eff and def<8 and needburst > 0 then return "chi"
		end
	end

	return "cancel"
end

local gongqi_skill = {}
gongqi_skill.name = "gongqi"
table.insert(sgs.ai_skills, gongqi_skill)
gongqi_skill.getTurnUseCard = function(self, inclusive)
	if self.player:hasUsed("GongqiCard") then return end
	local cards = self.player:getCards("he")
	cards = sgs.QList2Table(cards)
	if (self:isEquip("SilverLion") and self.player:isWounded())
		or (self:hasSkills("bazhen|yizhong") and self.player:getArmor()) then
		return sgs.Card_Parse("@GongqiCard=" .. self.player:getArmor():getEffectiveId())
	end

	for _, c in ipairs(cards) do
		if c:isKindOf("Weapon") then return sgs.Card_Parse("@GongqiCard=" .. c:getEffectiveId()) end
	end

	local handcards = self.player:getHandcards()
	handcards = sgs.QList2Table(handcards)
	local has_weapon, has_armor, has_def, has_off = false, false, false, false
	local weapon, armor
	for _, c in ipairs(handcards) do
		if c:isKindOf("Weapon") then
			has_weapon = true
			if not weapon or self:evaluateWeapon(weapon) < self:evaluateArmor(c) then weapon = c end
		end
		if c:isKindOf("Armor") then
			has_armor = true
			if not armor or self:evaluateArmor(armor) < self:evaluateArmor(c) then armor = c end
		end
		if c:isKindOf("DefensiveHorse") then has_def = true end
		if c:isKindOf("OffensiveHorse") then has_off = true end
	end
	if has_off and self.player:getOffensiveHorse() then return sgs.Card_Parse("@GongqiCard=" .. self.player:getOffensiveHorse():getEffectiveId()) end
	if has_def and self.player:getDefensiveHorse() then return sgs.Card_Parse("@GongqiCard=" .. self.player:getDefensiveHorse():getEffectiveId()) end
	if has_weapon and self.player:getWeapon() and self:evaluateWeapon(self.player:getWeapon()) <= self:evaluateWeapon(weapon) then
		return sgs.Card_Parse("@GongqiCard=" .. self.player:getWeapon():getEffectiveId())
	end
	if has_armor and self.player:getArmor() and self:evaluateArmor(self.player:getArmor()) <= self:evaluateArmor(armor) then
		return sgs.Card_Parse("@GongqiCard=" .. self.player:getArmor():getEffectiveId())
	end

	if self.player:getHandcardNum() > self.player:getHp() and self:getCardsNum("Slash") >= 1 then
		self:sortByKeepValue(handcards)
		for _, c in ipairs(handcards) do
			if c:isKindOf("Peach")
				or c:isKindOf("ExNihilo")
				or (c:isKindOf("Analeptic") and self.player:getHp() <= 2)
				or (c:isKindOf("Jink") and self:getCardsNum("Jink") < 2)
				or (c:isKindOf("Nullification") and self:getCardsNum("Nullification") < 2)
				or (c:isKindOf("Slash") and self:getCardsNum("Slash") == 1) then
				-- do nothing
			else
				return sgs.Card_Parse("@GongqiCard=" .. c:getEffectiveId())
			end
		end
	end
end

sgs.ai_skill_use_func.GongqiCard = function(card, use, self)
	use.card = card
end

sgs.ai_skill_invoke.gongqi = function(self, data)
	self:sort(self.enemies)
	for _, enemy in ipairs(self.enemies) do
		if not enemy:isNude() and not (enemy:isKongcheng() and self:hasSkills(sgs.lose_equip_skill, enemy)) then
			sgs.ai_skill_playerchosen.gongqi = enemy
			return true
		end
	end
end

sgs.ai_use_value.GongqiCard = 2
sgs.ai_use_priority.GongqiCard = 8

local jiefan_skill = {}
jiefan_skill.name = "jiefan"
table.insert(sgs.ai_skills, jiefan_skill)
jiefan_skill.getTurnUseCard = function(self, inclusive)
	if self.player:getMark("@rescue") == 0 then return end
	return sgs.Card_Parse("@JiefanCard=.")
end

sgs.ai_skill_use_func.JiefanCard = function(card, use, self)
	local target
	local use_value = 0
	local max_value = -10000
	for _, friend in ipairs(self.friends) do
		use_value = 0
		for _, p in sgs.qlist(self.room:getAllPlayers()) do
			if p:inMyAttackRange(friend) then
				if self:isFriend(p) then
					if not friend:hasSkill("manjuan") then use_value = use_value + 1 end
				else
					if p:getWeapon() then
						use_value = use_value + 1.2
					else
						if not friend:hasSkill("manjuan") then use_value = use_value + p:getHandcardNum() / 5 end
					end
				end
			end
		end
		use_value = use_value - friend:getHandcardNum() / 2
		if use_value > max_value then
			max_value = use_value
			target = friend
		end
	end

	if target and max_value >= self.player:aliveCount() / 2 then
		use.card = card
		if use.to then use.to:append(target) end
	end
end

sgs.ai_skill_cardask["@jiefan-discard"] = function(self, data)
	local player = data:toPlayer()
	if not player or not player:isAlive() or player:hasSkill("manjuan") or self:isFriend(player) then return "." end
	for _, card in sgs.qlist(self.player:getCards("he")) do
		if card:isKindOf("Weapon") and not self.player:hasEquip(card) then
			return "$" .. card:getEffectiveId()
		end
	end

	if not self.player:getWeapon() then return "." end
	local count = 0
	local range_fix = sgs.weapon_range[self.player:getWeapon():getClassName()] - 1

	for _, p in sgs.qlist(self.room:getAllPlayers()) do
		if self:isEnemy(p) and self.player:distanceTo(p, range_fix) > self.player:getAttackRange() then count = count + 1 end
	end

	if count <= 2 then return "$" .. self.player:getWeapon():getEffectiveId() end
	return "."
end

sgs.ai_card_intention.JiefanCard = -80

anxu_skill = {}
anxu_skill.name = "anxu"
table.insert(sgs.ai_skills, anxu_skill)
anxu_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("AnxuCard") then return nil end
	card=sgs.Card_Parse("@AnxuCard=.")
	return card

end

sgs.ai_skill_use_func.AnxuCard = function(card, use, self)
	local friends = {}
	for _, friend in ipairs(self.friends_noself) do
		if friend:hasSkill("manjuan") then
			if friend:hasSkill("kongcheng") and friend:isKongcheng() then
				table.insert(friends, friend)
			end
		elseif not (friend:hasSkill("kongcheng") and friend:isKongcheng()) then
			table.insert(friends, friend)
		end
	end
	self:sort(friends, "handcard")
	local least_friend, most_friend = friends[1], friends[#friends]
	local need_kongcheng_friend
	for _, friend in ipairs(friends) do
		if friend:getHandcardNum() == 1 and (friend:hasSkill("kongcheng") or (friend:hasSkill("zhiji") and friend:getMark("zhiji") == 0 and friend:getHp() >= 3)) then
			need_kongcheng_friend = friend
			break
		end
	end

	local enemies = {}
	for _, enemy in ipairs(self.enemies) do
		if not enemy:hasSkill("tuntian") and not (enemy:isKongcheng() or (enemy:getHandcardNum() <= 1 and self:needKongcheng(enemy))) then
			table.insert(enemies, enemy)
		end
	end
	self:sort(enemies, "handcard", true)
	local most_enemy = enemies[1]
	local prior_enemy, kongcheng_enemy, manjuan_enemy
	for _, enemy in ipairs(enemies) do
		if enemy:getHandcardNum() >= 2 and self:hasSkills("jijiu|qingnang|xinzhan|leiji|jieyin|beige|kanpo|liuli|qiaobian|zhiheng|guidao|longhun|xuanfeng|tianxiang|lijian", enemy) then
			if not prior_enemy then prior_enemy = enemy end
		end
		if enemy:hasSkill("kongcheng") and enemy:isKongcheng() then
			if not kongcheng_enemy then kongcheng_enemy = enemy end
		end
		if enemy:hasSkill("manjuan") then
			if not manjuan_enemy then manjuan_enemy = enemy end
		end
		if prior_enemy and kongcheng_enemy and manjuan_enemy then break end
	end

	-- Enemy -> Friend
	if least_friend then
		local tg_enemy = prior_enemy or most_enemy
		if tg_enemy and tg_enemy:getHandcardNum() > least_friend:getHandcardNum() then
			use.card = card
			if use.to then
				use.to:append(tg_enemy)
				use.to:append(least_friend)
			end
			return
		end
	end

	-- Friend -> Friend
	if #friends >= 2 then
		if need_kongcheng_friend and least_friend:isKongcheng() then
			use.card = card
			if use.to then
				use.to:append(need_kongcheng_friend)
				use.to:append(least_friend)
			end
			return
		elseif most_friend:getHandcardNum() >= 4 and most_friend:getHandcardNum() > least_friend:getHandcardNum() then
			use.card = card
			if use.to then
				use.to:append(most_friend)
				use.to:append(least_friend)
			end
			return
		end
	end

	-- Enemy -> Enemy
	if kongcheng_enemy and not kongcheng_enemy:hasSkill("manjuan") then
		local tg_enemy = prior_enemy or most_enemy
		if tg_enemy and not tg_enemy:isKongcheng() then
			use.card = card
			if use.to then
				use.to:append(tg_enemy)
				use.to:append(kongcheng_enemy)
			end
			return
		elseif most_friend and most_friend:getHandcardNum() >= 4 then -- Friend -> Enemy for KongCheng
			use.card = card
			if use.to then
				use.to:append(most_friend)
				use.to:append(kongcheng_enemy)
			end
			return
		end
	elseif manjuan_enemy then
		local tg_enemy = prior_enemy or most_enemy
		if tg_enemy and tg_enemy:getHandcardNum() > manjuan_enemy:getHandcardNum() then
			use.card = card
			if use.to then
				use.to:append(tg_enemy)
				use.to:append(manjuan_enemy)
			end
			return
		end
	elseif most_enemy then
		local tg_enemy, second_enemy
		if prior_enemy then
			for _, enemy in ipairs(enemies) do
				if enemy:getHandcardNum() < prior_enemy:getHandcardNum() then
					second_enemy = enemy
					tg_enemy = prior_enemy
					break
				end
			end
		end
		if not second_enemy then
			tg_enemy = most_enemy
			for _, enemy in ipairs(enemies) do
				if enemy:getHandcardNum() < most_enemy:getHandcardNum() then
					second_enemy = enemy
					break
				end
			end
		end
		if tg_enemy and second_enemy then
			use.card = card
			if use.to then
				use.to:append(tg_enemy)
				use.to:append(second_enemy)
				self.player:setFlags("anxu_isenemy_" .. second_enemy:objectName())
			end
			return
		end
	end
end

sgs.ai_card_intention.AnxuCard = function(card, from, to)
	local more, less
	if to[1]:getHandcardNum() > to[2]:getHandcardNum() then
		more = to[1]
		less = to[2]
	else
		more = to[2]
		less = to[1]
	end
	local intention = -50
	local kc_enemy = false
	if less:hasSkill("manjuan") or (less:hasSkill("kongcheng") and less:isKongcheng()) then
		kc_enemy = true
		intention = 80
	else
		if from:hasFlag("anxu_isenemy_" .. less:objectName()) then intention = -intention end
		intention = intention / (less:getHandcardNum() + 1)
	end
	sgs.updateIntention(from, less, intention)
	if kc_enemy then
		intention = 0
	elseif sgs.evaluateRoleTrends(more) ~= sgs.evaluateRoleTrends(less) then
		intention = -intention
	end
	sgs.updateIntention(from, more, intention)
end

sgs.ai_skill_invoke.zhuiyi = function(self, data)
	local damage = data:toDamageStar()
	local exclude = self.player
	if damage and damage.from then exclude = damage.from end

	local friends = self:getFriendsNoself()
	table.removeOne(friends, exclude)
	return #friends > 0
end

sgs.ai_skill_playerchosen.zhuiyi = function(self, targets)
	targets = sgs.QList2Table(targets)
	self:sort(targets,"defense")
	for _, friend in ipairs(targets) do
		if self:isFriend(friend) then
			return friend
		end
	end
end

sgs.ai_skill_invoke.lihuo = function(self, data)
	if not sgs.ai_skill_invoke.fan then return false end
	local use = data:toCardUse()
	for _, player in sgs.qlist(use.to) do
		if self:isEnemy(player) and not self:damageIsEffective(player) and self:damageIsEffective(player, sgs.DamageStruct_Fire) then return true end
	end
	return false
end

sgs.ai_view_as.lihuo = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card:isKindOf("Slash") and not (card:isKindOf("FireSlash") or card:isKindOf("ThunderSlash")) then
		return ("fire_slash:lihuo[%s:%s]=%d"):format(suit, number, card_id)
	end
end

local lihuo_skill = {}
lihuo_skill.name = "lihuo"
table.insert(sgs.ai_skills, lihuo_skill)
lihuo_skill.getTurnUseCard = function(self)
	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)
	local slash_card

	for _, card in ipairs(cards) do
		if card:isKindOf("Slash") and not (card:isKindOf("FireSlash") or card:isKindOf("ThunderSlash")) then
			slash_card = card
			break
		end
	end

	if not slash_card then return nil end
	if self.player:getHp() == 1 then return nil end
	local suit = slash_card:getSuitString()
	local number = slash_card:getNumberString()
	local card_id = slash_card:getEffectiveId()
	local card_str = ("fire_slash:lihuo[%s:%s]=%d"):format(suit, number, card_id)
	local fireslash = sgs.Card_Parse(card_str)
	assert(fireslash)

	return fireslash

end

sgs.ai_skill_use["@@chunlao"] = function(self, prompt)
	local slashcards = {} 
	local chunlao = self.player:getPile("wine")
	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)
	for _, card in ipairs(cards) do
		if card:isKindOf("Slash") then
			table.insert(slashcards, card:getId())
		end
	end
	if #slashcards > 0 and chunlao:isEmpty() then
		return "@ChunlaoCard=" .. table.concat(slashcards,"+") .. "->" .. "."
	end
	return "."
end

sgs.ai_skill_invoke.chunlao = function(self, data)
	local dying = data:toDying()
	return self:isFriend(dying.who) and self.player:getPile("wine"):length() > 0
end

sgs.chengpu_keep_value =
{
	Peach = 6,
	Jink = 5.1,
	Slash = 5.5,
}

sgs.ai_skill_invoke.zhiyu = function(self)
	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)
	local first
	local difcolor = 0
	for _, card in ipairs(cards) do
		if not first then first = card end
		if (first:isRed() and card:isBlack()) or (card:isRed() and first:isBlack()) then difcolor = 1 end
	end
	return difcolor == 0
end

local function get_handcard_suit(cards)
	if #cards == 0 then return sgs.Card_NoSuitNoColor end
	if #cards == 1 then return cards[1]:getSuit() end
	local black = false
	if cards[1]:isBlack() then black = true end
	for _, c in ipairs(cards) do
		if black ~= c:isBlack() then return sgs.Card_NoSuitNoColor end
	end
	if black then return sgs.Card_NoSuitBlack else return sgs.Card_NoSuitRed end
end

local qice_skill = {}
qice_skill.name = "qice"
table.insert(sgs.ai_skills, qice_skill)
qice_skill.getTurnUseCard = function(self)
	local cards = self.player:getHandcards()
	local allcard = {}
	cards = sgs.QList2Table(cards)
	local suit = get_handcard_suit(cards)
	local aoename = "savage_assault|archery_attack"
	local aoenames = aoename:split("|")
	local aoe
	local i
	local good, bad = 0, 0
	local caocao = self.room:findPlayerBySkillName("jianxiong")
	local qicetrick = "savage_assault|archery_attack|ex_nihilo|god_salvation"
	local qicetricks = qicetrick:split("|")
	local aoe_available, ge_available, ex_available = true, true, true
	for i = 1, #qicetricks do
		local forbiden = qicetricks[i]
		forbid = sgs.Sanguosha:cloneCard(forbiden, suit, 0)
		if self.player:isCardLimited(forbid, sgs.Card_MethodUse, true) or not forbid:isAvailable(self.player) then
			if forbid:isKindOf("AOE") then aoe_available = false end
			if forbid:isKindOf("GlobalEffect") then ge_available = false end
			if forbid:isKindOf("ExNihilo") then ex_available = false end
		end
	end
	if self.player:hasUsed("QiceCard") then return end
	for _, friend in ipairs(self.friends) do
		if friend:isWounded() then
			good = good + 10 / (friend:getHp())
			if friend:isLord() then good = good + 10 / (friend:getHp()) end
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

	for _, card in ipairs(cards) do
		table.insert(allcard, card:getId())
	end

	if self.player:getHandcardNum() < 3 then
		if aoe_available then
			for i = 1, #aoenames do
				local newqice = aoenames[i]
				aoe = sgs.Sanguosha:cloneCard(newqice, sgs.Card_NoSuitNoColor, 0)
				if self:getAoeValue(aoe) > -5 then
					local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. newqice)
					return parsed_card
				end
			end
		end
		if ge_available and good > bad then
			local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. "god_salvation")
			return parsed_card
		end
		if ex_available and self:getCardsNum("Jink") == 0 and self:getCardsNum("Peach") == 0 then
			local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. "ex_nihilo")
			return parsed_card
		end
	end

	if self.player:getHandcardNum() == 3 then
		if aoe_available then
			for i = 1, #aoenames do
				local newqice = aoenames[i]
				aoe = sgs.Sanguosha:cloneCard(newqice, sgs.Card_NoSuitNoColor, 0)
				if self:getAoeValue(aoe) > 0 then
					local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. newqice)
					return parsed_card
				end
			end
		end
		if ge_available and good > bad and self.player:isWounded() then
			local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. "god_salvation")
			return parsed_card
		end
		if ex_available and self:getCardsNum("Jink") == 0 and self:getCardsNum("Peach") == 0 and self:getCardsNum("Analeptic") == 0 and self:getCardsNum("Nullification") == 0 then
			local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. "ex_nihilo")
			return parsed_card
		end
	end
	if aoe_available then
		for i = 1, #aoenames do
			local newqice = aoenames[i]
			aoe = sgs.Sanguosha:cloneCard(newqice, sgs.Card_NoSuitNoColor, 0)
			if self:getAoeValue(aoe) > -5 and caocao and self:isFriend(caocao) and caocao:getHp() > 1 and not caocao:containsTrick("indulgence") then
				local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. newqice)
				return parsed_card
			end
		end
	end
	if self:getCardsNum("Jink") == 0 and self:getCardsNum("Peach") == 0 and self:getCardsNum("Analeptic") == 0 and self:getCardsNum("Nullification") == 0 then
		if ge_available and good > bad and self.player:isWounded() then
			local parsed_card = sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. "god_salvation")
			return parsed_card
		end
		if ex_available then
			local parsed_card=sgs.Card_Parse("@QiceCard=" .. table.concat(allcard,"+") .. ":" .. "ex_nihilo")
			return parsed_card
		end
	end
end

sgs.ai_skill_use_func.QiceCard = function(card, use, self)
	local userstring = card:toString()
	userstring = (userstring:split(":"))[3]
	local qicecard=sgs.Sanguosha:cloneCard(userstring, card:getSuit(), card:getNumber())
	self:useTrickCard(qicecard, use)
	if not use.card then return end
	use.card = card
end

sgs.ai_use_priority.QiceCard = 1.5