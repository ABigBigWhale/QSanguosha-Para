#ifndef _YJCM2013_H
#define _YJCM2013_H

#include "package.h"
#include "card.h"
#include "wind.h"

#include <QMutex>
#include <QGroupBox>
#include <QAbstractButton>

class YJCM2013Package: public Package {
    Q_OBJECT

public:
    YJCM2013Package();
};

class QiaoshuiCard: public SkillCard {
    Q_OBJECT

public:
    Q_INVOKABLE QiaoshuiCard();

    virtual bool targetFilter(const QList<const Player *> &targets, const Player *to_select, const Player *Self) const;
    virtual void use(Room *room, ServerPlayer *source, QList<ServerPlayer *> &targets) const;
};

class XiansiCard: public SkillCard {
    Q_OBJECT

public:
    Q_INVOKABLE XiansiCard();

    virtual bool targetFilter(const QList<const Player *> &targets, const Player *to_select, const Player *Self) const;
    virtual void onEffect(const CardEffectStruct &effect) const;
};

class XiansiSlashCard: public SkillCard {
    Q_OBJECT

public:
    Q_INVOKABLE XiansiSlashCard();

    virtual void use(Room *room, ServerPlayer *source, QList<ServerPlayer *> &targets) const;
};

#endif
