/*
    SPDX-FileCopyrightText: 2026 crabiosa

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <effect/effect.h>
#include <input.h>
#include <input_event.h>

namespace KWin
{

/**
 * Inverts horizontal touchpad swipes and turns three-finger vertical swipes
 * into four-finger ones (Overview upwards, Grid downwards).
 *
 * It draws nothing: it rewrites a couple of fields of the PointerSwipeGesture*
 * events and returns false, so KWin's own gesture handler evaluates them from
 * the modified data. That is what keeps the live preview and the switch on
 * release native.
 */
class SwipeRemapEffect : public Effect, public InputEventFilter
{
    Q_OBJECT

public:
    SwipeRemapEffect();
    ~SwipeRemapEffect() override;

    bool isActive() const override;

    bool swipeGestureBegin(PointerSwipeGestureBeginEvent *event) override;
    bool swipeGestureUpdate(PointerSwipeGestureUpdateEvent *event) override;
    bool swipeGestureEnd(PointerSwipeGestureEndEvent *event) override;
    bool swipeGestureCancelled(PointerSwipeGestureCancelEvent *event) override;

private:
    // Even with debug logging on, do not log every frame of a gesture: only the
    // first few, otherwise one quick attempt produces dozens of lines.
    static constexpr int s_loggedUpdates = 3;

    int m_fingers = 0;
    bool m_remapped = false;
    int m_updates = 0;
    qreal m_dx = 0.0;
    qreal m_dy = 0.0;
};

} // namespace KWin
