function SmartAI:useCardThunderSlash(...)
	self:useCardSlash(...)
end

sgs.ai_card_intention.ThunderSlash = sgs.ai_card_intention.Slash

sgs.ai_use_value.ThunderSlash = 4.5
sgs.ai_keep_value.ThunderSlash = 2.5
sgs.ai_use_priority.ThunderSlash = 2.5

function SmartAI:useCardFireSlash(...)
	self:useCardSlash(...)
end

sgs.ai_card_intention.FireSlash = sgs.ai_card_intention.Slash

sgs.ai_use_value.FireSlash = 4.4
sgs.ai_keep_value.FireSlash = 2.6
sgs.ai_use_priority.FireSlash = 2.6

sgs.weapon_range.Fan = 4
sgs.ai_use_priority.Fan = 2.655
sgs.ai_use_priority.Vine = 1.6

	
sgs.ai_skill_invoke.fan = function(self, data)
	local use = data:toCardUse()
	for _,target in sgs.qlist(use.to) do
		if self:isFriend(target) then
			if not (target:isChained() and self:isGoodChainTarget(target)) then return false end
		else
			if target:isChained() and not self:isGoodChainTarget(target) then return false end
		end
	end
	return true
end

sgs.ai_view_as.fan = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card:isKindOf("Slash") and not (card:isKindOf("FireSlash") or card:isKindOf("ThunderSlash")) then
		return ("fire_slash:fan[%s:%s]=%d"):format(suit, number, card_id)
	end
end

local fan_skill={}
fan_skill.name="fan"
table.insert(sgs.ai_skills,fan_skill)
fan_skill.getTurnUseCard=function(self)
	local cards = self.player:getCards("h")	
	cards=sgs.QList2Table(cards)
	local slash_card
	
	for _,card in ipairs(cards)  do
		if card:isKindOf("Slash") and not (card:isKindOf("FireSlash") or card:isKindOf("ThunderSlash")) then
			slash_card = card
			break
		end
	end
	
	if not slash_card  then return nil end
	local suit = slash_card:getSuitString()
	local number = slash_card:getNumberString()
	local card_id = slash_card:getEffectiveId()
	local card_str = ("fire_slash:fan[%s:%s]=%d"):format(suit, number, card_id)
	local fireslash = sgs.Card_Parse(card_str)
	assert(fireslash)
	
	return fireslash
		
end

function sgs.ai_weapon_value.fan(self, enemy)
	if enemy and self:isEquip("Vine", enemy) then return 3 end
end

function sgs.ai_armor_value.vine(player, self)
	if (self:needKongcheng(player) or player:hasSkill("lianying")) and player:getHandcardNum() == 1 then 
		return player:hasSkill("kongcheng") and 5 or 3.8
	end
	if self:hasSkills(sgs.lose_equip_skill, player) then return 3.8 end

	for _, enemy in ipairs(self:getEnemies(player)) do
		if (enemy:canSlash(player) and self:isEquip("Fan",enemy)) or self:hasSkills("huoji", enemy) then return -1 end
		if self:getCardsNum("FireSlash", enemy) or self:getCardsNum("FireAttack",enemy) then return -1 end
	end

	if #self.enemies < 3 or player:getHp() <= 2 then return 5 end
end

function SmartAI:searchForAnaleptic(use,enemy,slash)
	if not self.toUse then return nil end

	for _,card in ipairs(self.toUse) do
		if card:getId()~= slash:getId() then return nil end
	end

	if not use.to then return nil end
	if self.player:hasUsed("Analeptic") then return nil end

	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:fillSkillCards(cards)
	local allcards = self.player:getCards("he")
	allcards = sgs.QList2Table(allcards)

	if enemy:getArmor() and enemy:getArmor():objectName() == "silver_lion" then
		return
	end

	if ((enemy:getArmor() and enemy:getArmor():objectName() == "eight_diagram") or enemy:getHandcardNum() > 2) 
		and not ((self:isEquip("Axe") and #allcards > 4) or self.player:getHandcardNum() > 1+self.player:getHp()) then
		return
	end

	if self.player:getPhase() == sgs.Player_Play then
		if self.player:hasFlag("lexue") then
			local lexuesrc = sgs.Sanguosha:getCard(self.player:getMark("lexue"))
			if lexuesrc:isKindOf("Analeptic") then
				local cards = sgs.QList2Table(self.player:getHandcards())
				self:sortByUseValue(cards, true)
				for _, hcard in ipairs(cards) do
					if hcard:getSuit() == lexuesrc:getSuit() then
						local lexue = sgs.Sanguosha:cloneCard("analeptic", lexuesrc:getSuit(), lexuesrc:getNumber())
						lexue:addSubcard(hcard:getId())
						lexue:setSkillName("lexue")
						if self:getUseValue(lexuesrc) > self:getUseValue(hcard) then
							return lexue
						end
					end
				end
			end
		end

		if self.player:hasLordSkill("weidai") and not self.player:hasUsed("WeidaiCard") then
			return sgs.Card_Parse("@WeidaiCard=.")
		end
	end

	local card_str = self:getCardId("Analeptic")
	if card_str then return sgs.Card_Parse(card_str) end

	for _, anal in ipairs(cards) do
		if (anal:getClassName() == "Analeptic") and not (anal:getEffectiveId() == slash:getEffectiveId()) then
			return anal
		end
	end
end

sgs.dynamic_value.benefit.Analeptic = true

sgs.ai_use_value.Analeptic = 5.98
sgs.ai_keep_value.Analeptic = 4.5
sgs.ai_use_priority.Analeptic = 2.7

local function handcard_subtract_hp(a, b)
	local diff1 = a:getHandcardNum() - a:getHp()
	local diff2 = b:getHandcardNum() - b:getHp()

	return diff1 < diff2
end

function SmartAI:useCardSupplyShortage(card, use)
	local enemies = self:exclude(self.enemies, card)

	local zhanghe = self.room:findPlayerBySkillName("qiaobian")
	local zhanghe_seat = zhanghe and zhanghe:faceUp() and self:isEnemy(zhanghe) and zhanghe:getSeat() or 0

	if #enemies == 0 then return end

	local getvalue=function(enemy)
		if enemy:containsTrick("supply_shortage") or enemy:containsTrick("YanxiaoCard") or self:hasSkills("qiaobian", enemy) then return -100 end
		if zhanghe_seat > 0 then
			local gap1 = (enemy:getSeat() - self.player:getSeat()) % self.room:alivePlayerCount()
			local gap2 = (zhanghe_seat - self.player:getSeat()) % self.room:alivePlayerCount()
			if gap1 >= gap2 then return -100 end
		end

		local value = 0 - enemy:getHandcardNum()

		if self:hasSkills("yongsi|haoshi|tuxi|lijian|fanjian|neofanjian|dimeng|jijiu|jieyin",enemy) or (enemy:hasSkill("zaiqi") and enemy:getLostHp() > 1)
			then value = value + 10 
		end		
		if self:isWeak(enemy) then value = value + 5 end
		if enemy:isLord() then value = value + 3 end

		if self:objectiveLevel(enemy)<3 then value = value -10 end
		if not enemy:faceUp() then value = value -10 end
		if self:hasSkills("keji|shensu", enemy) then value = value - enemy:getHandcardNum() end
		if self:hasSkills("guanxing|xiuluo|tiandu|guidao", enemy) then value = value - 5 end
		if not sgs.isGoodTarget(enemy) then value = value - 1 end
		return value
	end

	local cmp = function(a,b)
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

sgs.ai_use_value.SupplyShortage = 7

sgs.ai_card_intention.SupplyShortage = 120

sgs.dynamic_value.control_usecard.SupplyShortage = true

function SmartAI:getChainedFriends()
	local chainedFriends = {}
	for _, friend in ipairs(self.friends) do
		if friend:isChained() then
			table.insert(chainedFriends,friend)
		end
	end
	return chainedFriends
end

function SmartAI:getChainedEnemies()
	local chainedEnemies = {}
	for _, enemy in ipairs(self.enemies) do
		if enemy:isChained() then
			table.insert(chainedEnemies,enemy)
		end
	end
	return chainedEnemies
end

function SmartAI:isGoodChainPartner(player)  
	player = player or self.player
	if player:hasSkill("buqu") or (self.player:hasSkill("niepan") and self.player:getMark("@nirvana") > 0) or player:getHp() > getBestHp(player)
		or self:getDamagedEffects(player) or (player:hasSkill("fuli") and player:getMark("@laoji") > 0) then 
		return true
	end
	return false
end

function SmartAI:isGoodChainTarget(who)
	local haslord
	local good = #(self:getChainedEnemies(self.player))
	local bad = #(self:getChainedFriends(self.player))
	for _, friend in ipairs(self:getChainedFriends(self.player)) do
		if self:cantbeHurt(friend) then
			return false
		end
		if self:isGoodChainPartner(friend) then 
			good = good+1 
		elseif self:isWeak(friend) and not friend:hasSkill("buqu") then 
			good = good-1 
		end
	end
	for _, enemy in ipairs(self:getChainedEnemies(self.player)) do
		if enemy:getHp() < 3 and not enemy:hasSkill("buqu") and enemy:getRole() == "lord" and self.player:getRole() == "renegade" then
			return false
		end
		if self:cantbeHurt(enemy) then
			return false
		end
		if self:isGoodChainPartner(enemy) then 
			bad = bad+1 
		elseif self:isWeak(enemy) and not enemy:hasSkill("buqu") then 
			bad = bad-1 
		end
	end
	return good > bad
end


function SmartAI:useCardIronChain(card, use)	
	use.card = card
	if #self.enemies == 1 and #(self:getChainedFriends()) <= 1 then return end
	if self:needBear() then return end
	local friendtargets = {}
	local otherfriends = {}
	local enemytargets = {}
	local yangxiu = self.room:findPlayerBySkillName("danlao")
	local liuxie = self.room:findPlayerBySkillName("huangen")
	self:sort(self.friends,"defense")
	for _, friend in ipairs(self.friends) do
		if friend:isChained() and not self:isGoodChainPartner(friend) and self:hasTrickEffective(card, friend) and not friend:hasSkill("danlao") then
			table.insert(friendtargets, friend)
		else
			table.insert(otherfriends, friend)
		end
	end
	if not (liuxie and self:isEnemy(liuxie)) then
		self:sort(self.enemies,"defense")
		for _, enemy in ipairs(self.enemies) do
			if not enemy:isChained() and not self.room:isProhibited(self.player, enemy, card) and not enemy:hasSkill("danlao")
				and self:hasTrickEffective(card, enemy) and not (self:objectiveLevel(enemy) <= 3) 
				and not self:getDamagedEffects(enemy) and not (enemy:getHp() > getBestHp(enemy)) and sgs.isGoodTarget(enemy,self.enemies) then
				table.insert(enemytargets, enemy)
			end
		end
	end
	
	local chainSelf = (self.player:getHp() > getBestHp(self.player) or self:getDamagedEffects(self.player)) and not self.player:isChained()
						and not self.player:hasSkill("jueqing")
						and (self:getCardId("NatureSlash") or (self:getCardId("Slash") and (self:hasWeapon("fan") or self:hasSkill("lihuo"))) 
						or (self:getCardId("FireAttack") and self:getHandcardNum() > 2))
	
	if not self.player:hasSkill("noswuyan") then
		if #friendtargets > 1 then
			if use.to then use.to:append(friendtargets[1]) end
			if use.to then use.to:append(friendtargets[2]) end
		elseif #friendtargets == 1 then
			if #enemytargets > 0 then
				if use.to then use.to:append(friendtargets[1]) end
				if use.to then use.to:append(enemytargets[1]) end
			elseif chainSelf then
				if use.to then use.to:append(friendtargets[1]) end
				if use.to then use.to:append(self.player) end
			elseif liuxie and self:isFriend(liuxie) and liuxie:getHp() > 0 and #otherfriends > 0 then
				if use.to then use.to:append(friendtargets[1]) end
				if use.to then use.to:append(otherfriends[1]) end
			elseif yangxiu and self:isFriend(yangxiu) then
				if use.to then use.to:append(friendtargets[1]) end
				if use.to then use.to:append(yangxiu) end
			end
		elseif #enemytargets > 1 then
			if use.to then use.to:append(enemytargets[1]) end
			if use.to then use.to:append(enemytargets[2]) end
		elseif #enemytargets == 1 then
			if chainSelf then
				if use.to then use.to:append(enemytargets[1]) end
				if use.to then use.to:append(self.player) end
			elseif liuxie and self:isFriend(liuxie) and liuxie:getHp() > 0 and #otherfriends > 0 then
				if use.to then use.to:append(enemytargets[1]) end
				if use.to then use.to:append(otherfriends[1]) end
			elseif yangxiu and self:isFriend(yangxiu) then
				if use.to then use.to:append(enemytargets[1]) end
				if use.to then use.to:append(yangxiu) end
			end
		elseif #friendtargets == 0 and #enemytargets == 0 then
			if liuxie and self:isFriend(liuxie) and #otherfriends > 0 then
				if liuxie:getHp() > 0 and use.to then use.to:append(otherfriends[1]) end
				if liuxie:getHp() > 1 and #otherfriends > 1 and use.to then use.to:append(otherfriends[2]) end
			end
		end
	end
	if use.to then assert(use.to:length() < 3) end
end

sgs.ai_card_intention.IronChain=function(card,from,tos)
	for _, to in ipairs(tos) do
		if to:isChained() then
			sgs.updateIntention(from, to, 80)
		else 
			sgs.updateIntention(from, to, -80)
		end
	end
end

sgs.ai_use_value.IronChain = 5.4
sgs.ai_use_priority.IronChain = 2.8

sgs.dynamic_value.benefit.IronChain = true

function SmartAI:useCardFireAttack(fire_attack, use)  
	if self.player:hasSkill("wuyan") then return end
	if self.player:hasSkill("noswuyan") then return end
	if self.player:hasFlag("LastFireAttackFailed") then return end

	local lack = {
		spade = true,
		club = true,
		heart = true,
		diamond = true,
	}

	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if card:getEffectiveId() ~= fire_attack:getEffectiveId() then
			lack[card:getSuitString()] = false
		end
	end

	if self.player:hasSkill("hongyan") then
		lack.spade = true
	end

	local suitnum = 0
	for suit,islack in pairs(lack) do
		if not islack then suitnum = suitnum + 1  end
	end


	self:sort(self.enemies, "defense")

	local can_attack = function(enemy)
		return self:objectiveLevel(enemy) > 3 and not enemy:isKongcheng() and not self.room:isProhibited(self.player, enemy, fire_attack) 
				and self:damageIsEffective(enemy, sgs.DamageStruct_Fire, self.player) and not self:cantbeHurt(enemy) 
				and self:hasTrickEffective(fire_attack, enemy)
				and sgs.isGoodTarget(enemy,self.enemies)
				and not (self:getDamagedEffects(enemy,self.player) and not self.player:hasSkill("jueqing"))
				and not (enemy:isChained() and not self:isGoodChainTarget(enemy) and not self.player:hasSkill("jueqing"))
	end

	local targets ={}
	for _, enemy in ipairs(self.enemies) do
		if can_attack(enemy) then		
			table.insert(targets,enemy)			
		end
	end


	if self.player:isChained() and self:isGoodChainTarget(self.player) and self.player:getHandcardNum() > 1 and not self.player:hasSkill("jueqing")
			and not self.room:isProhibited(self.player, self.player, fire_attack) 
			and self:damageIsEffective(self.player, sgs.DamageStruct_Fire, self.player) and not self:cantbeHurt(self.player) 
			and self:hasTrickEffective(fire_attack, self.player) 
			and (self.player:getHp()>1 or self:getCardsNum("Peach")>=1 or self:getCardsNum("Analeptic")>=1 or self.player:hasSkill("buqu")
				or (self.player:hasSkill("niepan") and self.player:getMark("@@nirvana") > 0)) then
		use.card = fire_attack
		if use.to then use.to:append(self.player) end
		return
	end

	if #targets==0 then return end

	for _, enemy in ipairs(targets) do
		if enemy:getHandcardNum() ==1 then
			local handcards = sgs.QList2Table(enemy:getHandcards())
			local flag=string.format("%s_%s_%s","visible",self.player:objectName(),enemy:objectName())
			if handcards[1]:hasFlag("visible") or handcards[1]:hasFlag(flag) then
				local suitstring = handcards[1]:getSuitString()
				if not lack[suitstring] then
					use.card = fire_attack
					if use.to then use.to:append(enemy) end
					return
				end
			end			
		end
	end

	if (suitnum == 2 and lack.diamond==false and lack.spade==false and self:getOverflow()<=0) or suitnum<=1 then return end

	for _, enemy in ipairs(targets) do
		if self:isEquip("Vine", enemy) or enemy:getMark("@kuangfeng") > 0 then
			use.card = fire_attack
			if use.to then use.to:append(enemy) end
			return
		end
	end
	for _, enemy in ipairs(targets) do
		use.card = fire_attack
		if use.to then use.to:append(enemy) end
		return
	end
end

sgs.ai_cardshow.fire_attack = function(self, requestor)
	local priority  =
	{
	heart = 4,
	spade = 3,
	club = 2,
	diamond = 1
	}
	if self.player:hasSkill("hongyan") then
		priority  =
		{
			heart = 4,
			spade = 0,
			club = 2,
			diamond = 1
		}
	end
	local index = 0
	local result
	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if priority[card:getSuitString()] > index then
			result = card
			index = priority[card:getSuitString()]
		end
	end
	if self.player:hasSkill("hongyan") and result:getSuit() == sgs.Card_Spade then
		result = sgs.Sanguosha:cloneCard(result:objectName(), sgs.Card_Heart, result:getNumber())
		result:setSkillName("hongyan")
	end

	return result
end

sgs.ai_use_value.FireAttack = 4.8
sgs.ai_use_priority.FireAttack = 2

sgs.ai_card_intention.FireAttack = 80
