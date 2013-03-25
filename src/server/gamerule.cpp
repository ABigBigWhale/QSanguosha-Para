#include "gamerule.h"
#include "serverplayer.h"
#include "room.h"
#include "standard.h"
#include "maneuvering.h"
#include "engine.h"
#include "settings.h"
#include "jsonutils.h"

#include <QTime>

GameRule::GameRule(QObject *)
    : TriggerSkill("game_rule")
{
    //@todo: this setParent is illegitimate in QT and is equivalent to calling
    // setParent(NULL). So taking it off at the moment until we figure out
    // a way to do it.
    //setParent(parent);

    events << GameStart << TurnStart
           << EventPhaseProceeding << EventPhaseEnd << EventPhaseChanging
           << CardUsed << CardFinished << CardEffected << PostCardEffected
           << PostHpReduced
           << EventLoseSkill << EventAcquireSkill
           << AskForPeaches << AskForPeachesDone << BuryVictim << GameOverJudge
           << SlashEffectStart << SlashHit << SlashEffected << SlashProceed
           << ConfirmDamage << DamageDone << DamageComplete
           << StartJudge << FinishRetrial << FinishJudge;

    skill_mark["niepan"] = "@nirvana";
    skill_mark["yeyan"] = "@flame";
    skill_mark["luanwu"] = "@chaos";
    skill_mark["fuli"] = "@laoji";
    skill_mark["jiefan"] = "@rescue";
    skill_mark["zuixiang"] = "@sleep";
    skill_mark["shichou"] = "@hate";
    skill_mark["fenxin"] = "@burnheart";
    skill_mark["xiongyi"] = "@arise";
    skill_mark["zhongyi"] = "@loyal";
}

bool GameRule::triggerable(const ServerPlayer *target) const{
    return true;
}

int GameRule::getPriority() const{
    return 0;
}

void GameRule::onPhaseProceed(ServerPlayer *player) const{
    Room *room = player->getRoom();
    switch(player->getPhase()) {
    case Player::PhaseNone: {
        Q_ASSERT(false);
        }
    case Player::RoundStart:{
            break;
        }
    case Player::Start: {
            break;
        }
    case Player::Judge: {
            QList<const Card *> tricks = player->getJudgingArea();
            while (!tricks.isEmpty() && player->isAlive()) {
                const Card *trick = tricks.takeLast();
                bool on_effect = room->cardEffect(trick, NULL, player);
                if (!on_effect)
                    trick->onNullified(player);
            }
            break;
        }
    case Player::Draw: {
            int num = 2;
            if (player->hasFlag("FirstRound")) {
                room->setPlayerFlag(player, "-FirstRound");
                if (room->getMode() == "02_1v1") num--;
            }

            QVariant data = num;
            room->getThread()->trigger(DrawNCards, room, player, data);
            int n = data.toInt();
            if (n > 0)
                player->drawCards(n);
            room->getThread()->trigger(AfterDrawNCards, room, player, QVariant::fromValue(n));
            break;
        }
    case Player::Play: {
            player->clearHistory();
            while (player->isAlive()) {
                CardUseStruct card_use;
                room->activate(player, card_use);
                if (card_use.card != NULL)
                    room->useCard(card_use);
                else
                    break;
            }
            break;
        }
    case Player::Discard: {
            int discard_num, keep_num;
            QSet<const Card *> jilei_cards;
            QList<const Card *> handcards;
            do {
                handcards = player->getHandcards();
                foreach (const Card *card, handcards) {
                    if (player->isJilei(card))
                        jilei_cards << card;
                }
                keep_num = qMax(player->getMaxCards(), jilei_cards.size());
                discard_num = player->getHandcardNum() - keep_num;
                jilei_cards.clear();
                if (discard_num > 0)
                    room->askForDiscard(player, "gamerule", discard_num, 1);
            } while (discard_num > 0);
            if (player->getHandcardNum() > player->getMaxCards())
                room->showAllCards(player);
            break;
        }
    case Player::Finish: {
            break;
        }
    case Player::NotActive:{
            break;
        }
    }
}

bool GameRule::trigger(TriggerEvent event, Room *room, ServerPlayer *player, QVariant &data) const{
    if (room->getTag("SkipGameRule").toBool()) {
        room->removeTag("SkipGameRule");
        return false;
    }

    // Handle global events
    if (player == NULL) {
        if (event == GameStart) {
            foreach (ServerPlayer *player, room->getPlayers()) {
                if (player->getGeneral()->getKingdom() == "god" && player->getGeneralName() != "anjiang") {
                    QString new_kingdom = room->askForKingdom(player);
                    room->setPlayerProperty(player, "kingdom", new_kingdom);

                    LogMessage log;
                    log.type = "#ChooseKingdom";
                    log.from = player;
                    log.arg = new_kingdom;
                    room->sendLog(log);
                }
            }
            room->setTag("FirstRound", true);
            room->drawCards(room->getPlayers(), 4, NULL);
        }
        return false;
    }

    switch (event) {
    case TurnStart: {
            player = room->getCurrent();
            if (room->getTag("FirstRound").toBool()) {
                room->setTag("FirstRound", false);
                room->setPlayerFlag(player, "FirstRound");
            }

            LogMessage log;
            log.type = "$AppendSeparator";
            room->sendLog(log);

            if (!player->faceUp()) {
                room->setPlayerFlag(player, "-FirstRound");
                player->turnOver();
            } else if (player->isAlive())
                player->play();

            break;
        }
    case EventPhaseProceeding: {
            onPhaseProceed(player);
            break;
        }
    case EventPhaseEnd: {
            if (player->getMark("drank") > 0) {
                LogMessage log;
                log.type = "#UnsetDrankEndOfTurn";
                log.from = player;
                room->sendLog(log);

                room->setPlayerMark(player, "drank", 0);
            }
            if (player->getPhase() == Player::Play)
                room->addPlayerHistory(player, ".");
            break;
        }
    case EventPhaseChanging: {
            PhaseChangeStruct change = data.value<PhaseChangeStruct>();
            if (change.to == Player::NotActive) {
                player->clearFlags();
                room->clearPlayerCardLimitation(player, true);
            }
            break;
        }
    case CardUsed: {
            if (data.canConvert<CardUseStruct>()) {
                CardUseStruct card_use = data.value<CardUseStruct>();
                const Card *card = card_use.card;
                if (card_use.from->hasFlag("GlobalFlag_ForbidSurrender")) {
                    card_use.from->setFlags("-GlobalFlag_ForbidSurrender");
                    room->doNotify(card_use.from, QSanProtocol::S_COMMAND_ENABLE_SURRENDER, Json::Value(true));
                }
                if (card_use.from->hasFlag("jijiang_failed"))
                    room->setPlayerFlag(card_use.from, "-jijiang_failed");

                RoomThread *thread = room->getThread();
                card_use.from->broadcastSkillInvoke(card);
                if (!card->getSkillName().isNull() && card->getSkillName(true) == card->getSkillName(false)
                    && card_use.m_isOwnerUse && card_use.from->hasSkill(card->getSkillName()))
                    room->notifySkillInvoked(card_use.from, card->getSkillName());

                if (card->hasPreAction())
                    card->doPreAction(room, card_use);

                ServerPlayer *target;
                QList<ServerPlayer *> targets = card_use.to;

                if (card_use.from && !card_use.to.empty()) {
                    foreach (ServerPlayer *to, card_use.to) {
                        target = to;
                        while (thread->trigger(TargetConfirming, room, target, data)) {
                            CardUseStruct new_use = data.value<CardUseStruct>();
                            target = new_use.to.at(targets.indexOf(target));
                            targets = new_use.to;
                        }
                    }
                }

                if (card_use.card->isKindOf("Slash") || card_use.card->isNDTrick()) {
                    foreach (ServerPlayer *p, card_use.to) {
                        QStringList card_list = p->tag["CurrentCardUse"].toStringList();
                        card_list << card_use.card->toString();
                        p->tag["CurrentCardUse"] = QVariant::fromValue(card_list);
                    }
                }

                card_use = data.value<CardUseStruct>();
                if (card_use.from) {
                    foreach (ServerPlayer *p, room->getAllPlayers())
                        thread->trigger(TargetConfirmed, room, p, data);
                }
                card->use(room, card_use.from, card_use.to);
            }

            break;
        }
    case CardFinished: {
            CardUseStruct use = data.value<CardUseStruct>();
            room->clearCardFlag(use.card);

            if (use.card->isKindOf("AOE") || use.card->isKindOf("GlobalEffect")) {
                foreach (ServerPlayer *p, room->getAlivePlayers())
                    room->doNotify(p, QSanProtocol::S_COMMAND_NULLIFICATION_ASKED, QSanProtocol::Utils::toJsonString("."));
            }

            break;
        }
    case EventAcquireSkill:
    case EventLoseSkill: {
            QString skill_name = data.toString();
            const Skill *skill = Sanguosha->getSkill(skill_name);
            bool refilter = skill->inherits("FilterSkill");

            if (refilter)
                room->filterCards(player, player->getCards("he"), event == EventLoseSkill);

            break;
        }
    case PostHpReduced: {
            if (player->getHp() > 0)
                break;
            if (data.canConvert<DamageStruct>()) {
                DamageStruct damage = data.value<DamageStruct>();
                room->enterDying(player, &damage);
            } else
                room->enterDying(player, NULL);

            break;
    }
    case AskForPeaches: {
            DyingStruct dying = data.value<DyingStruct>();
            const Card *peach = NULL;

            while (dying.who->getHp() <= 0) {
                peach = NULL;
                if (dying.who->isAlive())
                    peach = room->askForSinglePeach(player, dying.who);
                if (peach == NULL)
                    break;

                CardUseStruct use;
                use.card = peach;
                use.from = player;
                if (player != dying.who)
                    use.to << dying.who;

                room->useCard(use, false);
            }

            break;
        }
    case AskForPeachesDone: {
            if (player->getHp() <= 0 && player->isAlive()) {
                DyingStruct dying = data.value<DyingStruct>();
                room->killPlayer(player, dying.damage);
            }

            break;
        }
    case ConfirmDamage: {
            DamageStruct damage = data.value<DamageStruct>();
            if (damage.card && damage.to->getMark("SlashIsDrank") > 0) {
                LogMessage log;
                log.type = "#AnalepticBuff";
                log.from = damage.from;
                log.to << damage.to;
                log.arg = QString::number(damage.damage);

                damage.damage += damage.to->getMark("SlashIsDrank");
                damage.to->setMark("SlashIsDrank", 0);

                log.arg2 = QString::number(damage.damage);

                room->sendLog(log);

                data = QVariant::fromValue(damage);
            }

            break;
        }
    case DamageDone: {
            DamageStruct damage = data.value<DamageStruct>();
            if (damage.from && !damage.from->isAlive())
                damage.from = NULL;
            data = QVariant::fromValue(damage);
            if (damage.card && damage.card->isKindOf("Slash") && player->getMark("Qinggang_Armor_Nullified_Clear") == 0) {
                room->removePlayerMark(player, "Qinggang_Armor_Nullified"); // before reduce Hp
                room->addPlayerMark(player, "Qinggang_Armor_Nullified_Clear");
            }
            room->sendDamageLog(damage);

            room->applyDamage(player, damage);
            if (damage.nature != DamageStruct::Normal) {
                if (player->isChained() && !damage.chain) {
                    int n = room->getTag("is_chained").toInt();
                    n++;
                    room->setTag("is_chained", n);
                }
                room->setPlayerProperty(player, "chained", false);
            }
            room->getThread()->trigger(PostHpReduced, room, player, data);

            break;
        }
    case DamageComplete: {
            DamageStruct damage = data.value<DamageStruct>();
            if (player->getMark("Qinggang_Armor_Nullified_Clear") == 0) {
                if (damage.card && damage.card->isKindOf("Slash"))
                    room->removePlayerMark(player, "Qinggang_Armor_Nullified"); // otherwise
            } else
                room->setPlayerMark(player, "Qinggang_Armor_Nullified_Clear", 0);

            if (room->getTag("is_chained").toInt() > 0) {
                DamageStruct damage = data.value<DamageStruct>();
                if (damage.nature != DamageStruct::Normal && !damage.chain) {
                    // iron chain effect
                    int n = room->getTag("is_chained").toInt();
                    n--;
                    room->setTag("is_chained", n);
                    QList<ServerPlayer *> chained_players;
                    if (room->getCurrent()->isDead())
                        chained_players = room->getOtherPlayers(room->getCurrent());
                    else
                        chained_players = room->getAllPlayers();
                    foreach (ServerPlayer *chained_player, chained_players) {
                        if (chained_player->isChained()) {
                            room->getThread()->delay();
                            LogMessage log;
                            log.type = "#IronChainDamage";
                            log.from = chained_player;
                            room->sendLog(log);

                            DamageStruct chain_damage = damage;
                            chain_damage.to = chained_player;
                            chain_damage.chain = true;

                            room->damage(chain_damage);
                        }
                    }
                }
            }

            if (room->getMode() == "02_1v1" && player->isDead()) {
                if (!damage.card || !player->tag["CurrentCardUse"].toStringList().contains(damage.card->toString())) {
                    QString new_general = player->tag["1v1ChangeGeneral"].toString();
                    if (!new_general.isEmpty())
                        changeGeneral1v1(player);
                }
            }

            break;
        }
    case CardEffected: {
            if (data.canConvert<CardEffectStruct>()) {
                CardEffectStruct effect = data.value<CardEffectStruct>();
                if (room->isCanceled(effect)) {
                    effect.to->setFlags("GlobalFlag_NonSkillNullify");
                    return true;
                }
                if (effect.to->isAlive() || effect.card->isKindOf("Slash"))
                    effect.card->onEffect(effect);
            }

            break;
        }
    case PostCardEffected: {
            if (data.canConvert<CardEffectStruct>()) {
                CardEffectStruct effect = data.value<CardEffectStruct>();
                QStringList card_list = effect.to->tag["CurrentCardUse"].toStringList();
                if (effect.card && card_list.contains(effect.card->toString())) {
                    if (room->getMode() == "02_1v1" && effect.to->isDead()) {
                        QString new_general = effect.to->tag["1v1ChangeGeneral"].toString();
                        if (!new_general.isEmpty())
                            changeGeneral1v1(effect.to);
                    }
                    card_list.removeOne(effect.card->toString());
                    effect.to->tag["CurrentCardUse"] = QVariant::fromValue(card_list);
                }
            }
            break;
        }
    case SlashEffectStart: {
            SlashEffectStruct effect = data.value<SlashEffectStruct>();
            int n_nj = effect.from->getMark("no_jink" + effect.slash->toString());
            effect.from->setMark("no_jink" + effect.slash->toString(), n_nj / 10);

            if (effect.jink_num > 0) {
                if (n_nj % 10) {
                    effect.jink_num = 0;
                    data = QVariant::fromValue(effect);
                }
            }
            int n_dj = effect.from->getMark("double_jink" + effect.slash->toString());
            effect.from->setMark("double_jink" + effect.slash->toString(), n_dj / 10);
            if (effect.jink_num == 1) {
                if (n_dj % 10) {
                    effect.jink_num = 2;
                    data = QVariant::fromValue(effect);
                }
            }

            break;
        }
    case SlashEffected: {
            SlashEffectStruct effect = data.value<SlashEffectStruct>();

            QVariant data = QVariant::fromValue(effect);
            if (effect.jink_num > 0)
                room->getThread()->trigger(SlashProceed, room, effect.from, data);
            else
                room->slashResult(effect, NULL);
            break;
        }
    case SlashProceed: {
            SlashEffectStruct effect = data.value<SlashEffectStruct>();
            QString slasher = effect.from->objectName();
            if (!effect.to->isAlive())
                break;
            if (effect.jink_num == 2) {
                const Card *first_jink = NULL, *second_jink = NULL;
                Card *jink = NULL;
                first_jink = room->askForCard(effect.to, "jink", "@double-jink-1:" + slasher, QVariant(), Card::MethodUse, effect.from);
                if (room->isJinkEffected(effect.to, first_jink)) {
                    second_jink = room->askForCard(effect.to, "jink", "@double-jink-2:" + slasher, QVariant(), Card::MethodUse, effect.from);
                    if (room->isJinkEffected(effect.to, second_jink)) {
                        jink = new DummyCard;
                        jink->addSubcard(first_jink);
                        jink->addSubcard(second_jink);
                    }
                }

                room->slashResult(effect, jink);
            } else {
                const Card *jink = room->askForCard(effect.to, "jink", "slash-jink:" + slasher, data, Card::MethodUse, effect.from);
                room->slashResult(effect, room->isJinkEffected(effect.to, jink) ? jink : NULL);
            }

            break;
        }
    case SlashHit: {
            SlashEffectStruct effect = data.value<SlashEffectStruct>();

            DamageStruct damage;
            damage.card = effect.slash;
            damage.from = effect.from;
            damage.to = effect.to;
            damage.nature = effect.nature;
            if (effect.drank > 0) damage.to->setMark("SlashIsDrank", effect.drank);
            room->damage(damage);

            break;
        }
    case GameOverJudge: {
            if (room->getMode() == "02_1v1") {
                QStringList list = player->tag["1v1Arrange"].toStringList();
                if (!list.isEmpty())
                    return false;
            }

            QString winner = getWinner(player);
            if (!winner.isNull()) {
                room->gameOver(winner);
                return true;
            }

            break;
        }
    case BuryVictim: {
            DeathStruct death = data.value<DeathStruct>();
            player->bury();

            if (room->getTag("SkipNormalDeathProcess").toBool())
                return false;

            ServerPlayer *killer = death.damage ? death.damage->from : NULL;
            if (killer)
                rewardAndPunish(killer, player);

            if (room->getMode() == "02_1v1") {
                QStringList list = player->tag["1v1Arrange"].toStringList();

                if (!list.isEmpty()) {
                    player->tag["1v1ChangeGeneral"] = list.takeFirst();
                    player->tag["1v1Arrange"] = list;

                    QStringList card_list = player->tag["CurrentCardUse"].toStringList();
                    if (death.damage == NULL && card_list.isEmpty()) {
                        changeGeneral1v1(player);
                        return false;
                    }
                }
            } else if (room->getMode() == "06_XMode") {
                changeGeneralXMode(player);
                return false;
            }

            break;
        }
    case StartJudge: {
            int card_id = room->drawCard();

            JudgeStar judge = data.value<JudgeStar>();
            judge->card = Sanguosha->getCard(card_id);

            LogMessage log;
            log.type = "$InitialJudge";
            log.from = player;
            log.card_str = QString::number(judge->card->getEffectiveId());
            room->sendLog(log);

            room->moveCardTo(judge->card, NULL, judge->who, Player::PlaceJudge,
                             CardMoveReason(CardMoveReason::S_REASON_JUDGE,
                             judge->who->objectName(),
                             QString(), QString(), judge->reason), true);
            judge->updateResult();
            break;
        }
    case FinishRetrial: {
            JudgeStar judge = data.value<JudgeStar>();

            LogMessage log;
            log.type = "$JudgeResult";
            log.from = player;
            log.card_str = QString::number(judge->card->getEffectiveId());
            room->sendLog(log);

            int delay = Config.AIDelay;
            if (judge->time_consuming) delay /= 1.25;
            room->getThread()->delay(delay);
            if (judge->play_animation) {
                room->sendJudgeResult(judge);
                room->getThread()->delay(Config.S_JUDGE_LONG_DELAY);
            }

            room->removeTag("retrial");

            break;
        }
    case FinishJudge: {
            JudgeStar judge = data.value<JudgeStar>();

            if (room->getCardPlace(judge->card->getEffectiveId()) == Player::PlaceJudge) {
                CardMoveReason reason(CardMoveReason::S_REASON_JUDGEDONE, judge->who->objectName(), QString(), judge->reason);
                room->moveCardTo(judge->card, judge->who, NULL, Player::DiscardPile, reason, true);
            }

            break;
        }
    default:
            break;
    }

    return false;
}

void GameRule::changeGeneral1v1(ServerPlayer *player) const{
    Config.AIDelay = Config.OriginAIDelay;

    Room *room = player->getRoom();
    QString new_general = player->tag["1v1ChangeGeneral"].toString();
    player->tag.remove("1v1ChangeGeneral");
    room->revivePlayer(player);
    room->changeHero(player, new_general, true, true);
    if (player->getGeneral()->getKingdom() == "god") {
        QString new_kingdom = room->askForKingdom(player);
        room->setPlayerProperty(player, "kingdom", new_kingdom);

        LogMessage log;
        log.type = "#ChooseKingdom";
        log.from = player;
        log.arg = new_kingdom;
        room->sendLog(log);
    }
    player->clearHistory();

    if (player->getKingdom() != player->getGeneral()->getKingdom())
        room->setPlayerProperty(player, "kingdom", player->getGeneral()->getKingdom());

    room->doBroadcastNotify(room->getOtherPlayers(player, true), QSanProtocol::S_COMMAND_REVEAL_GENERAL,
                            QSanProtocol::Utils::toJsonArray(player->objectName(), new_general));

    if (!player->faceUp())
        player->turnOver();

    if (player->isChained())
        room->setPlayerProperty(player, "chained", false);

    room->setTag("FirstRound", true); //For Manjuan
    player->drawCards(4);
    room->setTag("FirstRound", false);
}

void GameRule::changeGeneralXMode(ServerPlayer *player) const{
    Config.AIDelay = Config.OriginAIDelay;

    Room *room = player->getRoom();
    PlayerStar leader = player->tag["XModeLeader"].value<PlayerStar>();
    Q_ASSERT(leader);
    QStringList backup = leader->tag["XModeBackup"].toStringList();
    QString general = room->askForGeneral(leader, backup);
    if (backup.contains(general))
        backup.removeOne(general);
    else
        backup.takeFirst();
    leader->tag["XModeBackup"] = QVariant::fromValue(backup);
    room->revivePlayer(player);
    room->changeHero(player, general, true, true);
    if (player->getGeneral()->getKingdom() == "god") {
        QString new_kingdom = room->askForKingdom(player);
        room->setPlayerProperty(player, "kingdom", new_kingdom);

        LogMessage log;
        log.type = "#ChooseKingdom";
        log.from = player;
        log.arg = new_kingdom;
        room->sendLog(log);
    }
    player->clearHistory();

    if (player->getKingdom() != player->getGeneral()->getKingdom())
        room->setPlayerProperty(player, "kingdom", player->getGeneral()->getKingdom());

    if (!player->faceUp())
        player->turnOver();

    if (player->isChained())
        room->setPlayerProperty(player, "chained", false);

    room->setTag("FirstRound", true); //For Manjuan
    player->drawCards(4);
    room->setTag("FirstRound", false);
}

void GameRule::rewardAndPunish(ServerPlayer *killer, ServerPlayer *victim) const{
    if (killer->isDead() || killer->getRoom()->getMode() == "06_XMode")
        return;

    if (killer->getRoom()->getMode() == "06_3v3") {
        if (Config.value("3v3/OfficialRule", "2012").toString().startsWith("201"))
            killer->drawCards(2);
        else
            killer->drawCards(3);
    } else {
        if (victim->getRole() == "rebel" && killer != victim)
            killer->drawCards(3);
        else if (victim->getRole() == "loyalist" && killer->getRole() == "lord")
            killer->throwAllHandCardsAndEquips();
    }
}

QString GameRule::getWinner(ServerPlayer *victim) const{
    Room *room = victim->getRoom();
    QString winner;

    if (room->getMode() == "06_3v3") {
        switch (victim->getRoleEnum()) {
        case Player::Lord: winner = "renegade+rebel"; break;
        case Player::Renegade: winner = "lord+loyalist"; break;
        default:
            break;
        }
    } else if (room->getMode() == "06_XMode") {
        QString role = victim->getRole();
        PlayerStar leader = victim->tag["XModeLeader"].value<PlayerStar>();
        if (leader->tag["XModeBackup"].toStringList().isEmpty()) {
            if (role.startsWith('r'))
                winner = "lord+loyalist";
            else
                winner = "renegade+rebel";
        }
    } else if (Config.EnableHegemony) {
        bool has_anjiang = false, has_diff_kingdoms = false;
        QString init_kingdom;
        foreach (ServerPlayer *p, room->getAlivePlayers()) {
            if (room->getTag(p->objectName()).toStringList().size())
                has_anjiang = true;

            if (init_kingdom.isEmpty())
                init_kingdom = p->getKingdom();
            else if (init_kingdom != p->getKingdom())
                has_diff_kingdoms = true;
        }

        if (!has_anjiang && !has_diff_kingdoms) {
            QStringList winners;
            QString aliveKingdom = room->getAlivePlayers().first()->getKingdom();
            foreach (ServerPlayer *p, room->getPlayers()) {
                if (p->isAlive()) winners << p->objectName();
                if (p->getKingdom() == aliveKingdom) {
                    QStringList generals = room->getTag(p->objectName()).toStringList();
                    if (generals.size() && !Config.Enable2ndGeneral) continue;
                    if (generals.size() > 1) continue;

                    //if someone showed his kingdom before death,
                    //he should be considered victorious as well if his kingdom survives
                    winners << p->objectName();
                }
            }
            winner = winners.join("+");
        }
        if (!winner.isNull()) {
            foreach (ServerPlayer *player, room->getAllPlayers()) {
                if (player->getGeneralName() == "anjiang") {
                    QStringList generals = room->getTag(player->objectName()).toStringList();
                    room->changePlayerGeneral(player, generals.at(0));

                    room->setPlayerProperty(player, "kingdom", player->getGeneral()->getKingdom());
                    room->setPlayerProperty(player, "role", BasaraMode::getMappedRole(player->getKingdom()));

                    generals.takeFirst();
                    room->setTag(player->objectName(), QVariant::fromValue(generals));
                }
                if (Config.Enable2ndGeneral && player->getGeneral2Name() == "anjiang") {
                    QStringList generals = room->getTag(player->objectName()).toStringList();
                    room->changePlayerGeneral2(player, generals.at(0));
                }
            }
        }
    } else {
        QStringList alive_roles = room->aliveRoles(victim);
        switch (victim->getRoleEnum()) {
        case Player::Lord: {
                if (alive_roles.length() == 1 && alive_roles.first() == "renegade")
                    winner = room->getAlivePlayers().first()->objectName();
                else
                    winner = "rebel";
                break;
            }
        case Player::Rebel:
        case Player::Renegade: {
                if (!alive_roles.contains("rebel") && !alive_roles.contains("renegade")) {
                    winner = "lord+loyalist";
                    if (victim->getRole() == "renegade" && !alive_roles.contains("loyalist"))
                        room->setTag("RenegadeInFinalPK", true);
                }
                break;
            }
        default:
                break;
        }
    }

    return winner;
}

HulaoPassMode::HulaoPassMode(QObject *parent)
    : GameRule(parent)
{
    setObjectName("hulaopass_mode");
    events << HpChanged << StageChange;
    default_choice = "recover";
}

bool HulaoPassMode::trigger(TriggerEvent event, Room *room, ServerPlayer *player, QVariant &data) const{
    switch (event) {
    case StageChange: {
            ServerPlayer *lord = room->getLord();
            room->setPlayerMark(lord, "secondMode", 1);
            room->changeHero(lord, "shenlvbu2", true, true);
            room->doLightbox("$StageChange", 5000);

            QList<const Card *> tricks = lord->getJudgingArea();
            foreach (const Card *trick, tricks) {
                CardMoveReason reason(CardMoveReason::S_REASON_NATURAL_ENTER, QString());
                room->throwCard(trick, reason, NULL);
            }
            break;
        }
    case GameStart: {
            // Handle global events
            if (player == NULL) {
                ServerPlayer *lord = room->getLord();
                lord->drawCards(8);
                foreach (ServerPlayer *player, room->getPlayers()) {
                    if (!player->isLord())
                        player->drawCards(player->getSeat() + 1);
                }
                return false;
            }
            break;
        }
    case CardUsed: {
            CardUseStruct use = data.value<CardUseStruct>();
            if (use.card->isKindOf("Weapon")
                && (player->isCardLimited(use.card, Card::MethodUse)
                    || player->askForSkillInvoke("weapon_recast", data))) {
                CardMoveReason reason(CardMoveReason::S_REASON_RECAST, player->objectName());
                reason.m_skillName = "weapon_recast";
                room->moveCardTo(use.card, player, NULL, Player::DiscardPile, reason);
                player->broadcastSkillInvoke("@recast");

                LogMessage log;
                log.type = "#Card_Recast";
                log.from = player;
                log.card_str = use.card->toString();
                room->sendLog(log);

                player->drawCards(1);
                return false;
            }

            break;
        }
    case HpChanged: {
            if (player->isLord() && player->getHp() <= 4 && player->getMark("secondMode") == 0)
                throw StageChange;
            return false;
        }
    case GameOverJudge: {
            if (player->isLord())
                room->gameOver("rebel");
            else
                if (room->aliveRoles(player).length() == 1)
                    room->gameOver("lord");

            return false;
        }
    case BuryVictim: {
            if (player->hasFlag("actioned")) room->setPlayerFlag(player, "-actioned");

            LogMessage log;
            log.type = "#Reforming";
            log.from = player;
            room->sendLog(log);

            player->bury();
            room->setPlayerProperty(player, "hp", 0);

            foreach (ServerPlayer *p, room->getOtherPlayers(room->getLord())) {
                if (p->isAlive() && p->askForSkillInvoke("draw_1v3"))
                    p->drawCards(1);
            }

            break;
        }
    case TurnStart: {
            if (player->isLord()) {
                LogMessage log;
                log.type = "$AppendSeparator";
                room->sendLog(log);

                if (!player->faceUp())
                    player->turnOver();
                else
                    player->play();
            } else {
                if (player->isDead()) {
                    Json::Value arg(Json::arrayValue);
                    arg[0] = (int)QSanProtocol::S_GAME_EVENT_PLAYER_REFORM;
                    arg[1] = QSanProtocol::Utils::toJsonString(player->objectName());
                    room->doBroadcastNotify(QSanProtocol::S_COMMAND_LOG_EVENT, arg);

                    QString choice = player->isWounded() ? "recover" : "draw";
                    if (player->isWounded() && player->getHp() > 0)
                        choice = room->askForChoice(player, "Hulaopass", "recover+draw");

                    if (choice == "draw") {
                        LogMessage log;
                        log.type = "#ReformingDraw";
                        log.from = player;
                        log.arg = "1";
                        room->sendLog(log);
                        player->drawCards(1, "reform");
                    } else {
                        LogMessage log;
                        log.type = "#ReformingRecover";
                        log.from = player;
                        log.arg = "1";
                        room->sendLog(log);
                        room->setPlayerProperty(player, "hp", player->getHp() + 1);
                    }

                    if (player->getHp() + player->getHandcardNum() == 6) {
                        LogMessage log;
                        log.type = "#ReformingRevive";
                        log.from = player;
                        room->sendLog(log);

                        room->revivePlayer(player);
                    }
                } else {
                    LogMessage log;
                    log.type = "$AppendSeparator";
                    room->sendLog(log);

                    if (!player->faceUp())
                        player->turnOver();
                    else
                        player->play();
                }
            }

            return false;
        }
    default:
        break;
    }

    return GameRule::trigger(event, room, player, data);
}

BasaraMode::BasaraMode(QObject *parent)
    : GameRule(parent)
{
    setObjectName("basara_mode");
    events << EventPhaseStart << DamageInflicted << BeforeGameOverJudge;
}

QString BasaraMode::getMappedRole(const QString &role) {
    static QMap<QString, QString> roles;
    if (roles.isEmpty()) {
        roles["wei"] = "lord";
        roles["shu"] = "loyalist";
        roles["wu"] = "rebel";
        roles["qun"] = "renegade";
    }
    return roles[role];
}

int BasaraMode::getPriority() const{
    return 15;
}

void BasaraMode::playerShowed(ServerPlayer *player) const{
    Room *room = player->getRoom();
    QStringList names = room->getTag(player->objectName()).toStringList();
    if (names.isEmpty())
        return;

    if (Config.EnableHegemony) {
        QMap<QString, int> kingdom_roles;
        foreach (ServerPlayer *p, room->getOtherPlayers(player))
            kingdom_roles[p->getKingdom()]++;

        if (kingdom_roles[Sanguosha->getGeneral(names.first())->getKingdom()] >= Config.value("HegemonyMaxShown", 2).toInt()
            && player->getGeneralName() == "anjiang")
            return;
    }

    QString answer = room->askForChoice(player, "RevealGeneral", "yes+no");
    if (answer == "yes") {
        QString general_name = room->askForGeneral(player, names);

        generalShowed(player, general_name);
        if (Config.EnableHegemony) room->getThread()->trigger(GameOverJudge, room, player);
        playerShowed(player);
    }
}

void BasaraMode::generalShowed(ServerPlayer *player, QString general_name) const{
    Room *room = player->getRoom();
    QStringList names = room->getTag(player->objectName()).toStringList();
    if (names.isEmpty()) return;

    if (player->getGeneralName() == "anjiang") {
        room->changeHero(player, general_name, false, false, false, false);
        room->setPlayerProperty(player, "kingdom", player->getGeneral()->getKingdom());

        if (player->getGeneral()->getKingdom() == "god") {
            QString new_kingdom = room->askForKingdom(player);
            room->setPlayerProperty(player, "kingdom", new_kingdom);

            LogMessage log;
            log.type = "#ChooseKingdom";
            log.from = player;
            log.arg = new_kingdom;
            room->sendLog(log);
        }

        if (Config.EnableHegemony)
            room->setPlayerProperty(player, "role", getMappedRole(player->getKingdom()));
        foreach (QString skill_name, GameRule::skill_mark.keys()) {
            if (player->hasSkill(skill_name, true))
                room->addPlayerMark(player, GameRule::skill_mark[skill_name]);
        }
    } else {
        room->changeHero(player, general_name, false, false, true, false);
        foreach (QString skill_name, GameRule::skill_mark.keys()) {
            if (player->hasSkill(skill_name, true))
                room->addPlayerMark(player, GameRule::skill_mark[skill_name]);
        }
    }

    room->getThread()->addPlayerSkills(player);

    names.removeOne(general_name);
    room->setTag(player->objectName(), QVariant::fromValue(names));

    LogMessage log;
    log.type = "#BasaraReveal";
    log.from = player;
    log.arg  = player->getGeneralName();
    log.arg2 = player->getGeneral2Name();

    room->sendLog(log);
}

bool BasaraMode::trigger(TriggerEvent event, Room *room, ServerPlayer *player, QVariant &data) const{
    // Handle global events
    if (player == NULL) {
        if (event == GameStart) {
            if (Config.EnableHegemony)
                room->setTag("SkipNormalDeathProcess", true);
            foreach (ServerPlayer *sp, room->getAlivePlayers()) {
                room->setPlayerProperty(sp, "general", "anjiang");
                sp->setGender(General::SexLess);
                room->setPlayerProperty(sp, "kingdom", "god");

                LogMessage log;
                log.type = "#BasaraGeneralChosen";
                log.arg = room->getTag(sp->objectName()).toStringList().at(0);

                if (Config.Enable2ndGeneral) {
                    room->setPlayerProperty(sp, "general2", "anjiang");
                    log.arg2 = room->getTag(sp->objectName()).toStringList().at(1);
                }

                room->doNotify(sp, QSanProtocol::S_COMMAND_LOG_SKILL, log.toJsonValue());
                sp->tag["roles"] = room->getTag(sp->objectName()).toStringList().join("+");
            }
        }
        return false;
    }

    player->tag["event"] = event;
    player->tag["event_data"] = data;

    switch (event) {
    case CardEffected: {
            if (player->getPhase() == Player::NotActive) {
                CardEffectStruct ces = data.value<CardEffectStruct>();
                if (ces.card)
                    if (ces.card->isKindOf("TrickCard") || ces.card->isKindOf("Slash"))
                        playerShowed(player);

                const ProhibitSkill *prohibit = room->isProhibited(ces.from, ces.to, ces.card);
                if (prohibit) {
                    LogMessage log;
                    log.type = "#SkillAvoid";
                    log.from = ces.to;
                    log.arg  = prohibit->objectName();
                    log.arg2 = ces.card->objectName();
                    room->sendLog(log);

                    return true;
                }
            }
            break;
        }
    case EventPhaseStart: {
            if (player->getPhase() == Player::RoundStart)
                playerShowed(player);

            break;
        }
    case DamageInflicted: {
            playerShowed(player);
            break;
        }
    case BeforeGameOverJudge: {
            if (player->getGeneralName() == "anjiang") {
                QStringList generals = room->getTag(player->objectName()).toStringList();
                room->changePlayerGeneral(player, generals.at(0));

                room->setPlayerProperty(player, "kingdom", player->getGeneral()->getKingdom());
                if (Config.EnableHegemony)
                    room->setPlayerProperty(player, "role", getMappedRole(player->getKingdom()));

                generals.takeFirst();
                room->setTag(player->objectName(), QVariant::fromValue(generals));
            }
            if (Config.Enable2ndGeneral && player->getGeneral2Name() == "anjiang") {
                QStringList generals = room->getTag(player->objectName()).toStringList();
                room->changePlayerGeneral2(player, generals.at(0));
            }
            break;
        }
    case BuryVictim: {
            DeathStruct death = data.value<DeathStruct>();
            player->bury();
            if (Config.EnableHegemony) {
                ServerPlayer *killer = death.damage ? death.damage->from : NULL;
                if (killer && killer->getKingdom() != "god") {
                    if (killer->getKingdom() == player->getKingdom())
                        killer->throwAllHandCardsAndEquips();
                    else if (killer->isAlive())
                        killer->drawCards(3);
                }
                return true;
            }

            break;
        }
    default:
        break;
    }
    return false;
}

