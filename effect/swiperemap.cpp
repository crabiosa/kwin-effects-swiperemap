/*
    SPDX-FileCopyrightText: 2026 crabiosa

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "swiperemap.h"

#include <config-kwin.h>

#include <QLoggingCategory>

namespace KWin
{

Q_LOGGING_CATEGORY(KWIN_EFFECT_SWIPEREMAP, "kwin_effect_swiperemap", QtInfoMsg)

SwipeRemapEffect::SwipeRemapEffect()
    // Like InputActions: LockScreen runs before GlobalShortcut, which swallows
    // gestures with 3+ fingers, and before Effects.
    : InputEventFilter(InputFilterOrder::LockScreen)
{
    input()->installInputEventFilter(this);

    // The life cycle message is the only line at info level: it appears once
    // per KWin start. Gesture events are debug (see qCDebug below), otherwise
    // the journal grows with every gesture forever.
    qCInfo(KWIN_EFFECT_SWIPEREMAP) << "swiperemap loaded against kwin" << KWIN_VERSION_STRING << "- remap active";
}

SwipeRemapEffect::~SwipeRemapEffect() = default;

bool SwipeRemapEffect::isActive() const
{
    // Nothing is painted; loadEffect() does not check isActive(), so the effect
    // stays loaded and the filter keeps receiving events.
    return false;
}

bool SwipeRemapEffect::swipeGestureBegin(PointerSwipeGestureBeginEvent *event)
{
    m_fingers = event->fingerCount;
    m_remapped = false;
    m_updates = 0;
    m_dx = 0.0;
    m_dy = 0.0;

    // 3 -> 4: the gesture now matches Overview (up) / Grid (down). With a
    // single row of desktops three-finger vertical swipes are a no-op anyway,
    // so nothing is lost.
    if (event->fingerCount == 3) {
        event->fingerCount = 4;
        m_remapped = true;
    }

    qCDebug(KWIN_EFFECT_SWIPEREMAP) << "begin: fingers" << m_fingers << "->" << event->fingerCount;
    return false;
}

bool SwipeRemapEffect::swipeGestureUpdate(PointerSwipeGestureUpdateEvent *event)
{
    m_dx += event->delta.x();
    m_dy += event->delta.y();
    ++m_updates;

    if (m_updates <= s_loggedUpdates) {
        qCDebug(KWIN_EFFECT_SWIPEREMAP) << "update" << m_updates << "delta" << event->delta << "sum" << QPointF(m_dx, m_dy);
    }

    // Mirror the horizontal axis. KWin picks the axis by |dx| > |dy| and
    // inverting does not change the magnitude, so vertical gestures
    // (Overview/Grid) stay intact.
    event->delta.setX(-event->delta.x());
    return false;
}

bool SwipeRemapEffect::swipeGestureEnd(PointerSwipeGestureEndEvent *event)
{
    Q_UNUSED(event)
    qCDebug(KWIN_EFFECT_SWIPEREMAP) << "end after" << m_updates << "updates; sum" << QPointF(m_dx, m_dy)
                                    << (m_remapped ? "(3 fingers remapped to 4)" : "(fingers kept)");
    return false;
}

bool SwipeRemapEffect::swipeGestureCancelled(PointerSwipeGestureCancelEvent *event)
{
    Q_UNUSED(event)
    qCDebug(KWIN_EFFECT_SWIPEREMAP) << "cancelled after" << m_updates << "updates; sum" << QPointF(m_dx, m_dy);
    return false;
}

} // namespace KWin

KWIN_EFFECT_FACTORY(KWin::SwipeRemapEffect, "metadata.json")

// The factory is declared in this .cpp, so its moc output goes here instead of
// mocs_compilation.cpp. Without this include Q_PLUGIN_METADATA never reaches the
// .so and KWin does not see the plugin at all.
#include "swiperemap.moc"
