# Smooth wheel scroll

## What it is

A `ScrollController` whose positions animate mouse wheel input toward an
accumulated target instead of jumping, by overriding
`ScrollPositionWithSingleContext.pointerScroll`.

## Governing decisions

**None.** Issue #1 specifies it; no decision record exists.

## Design model

- Wheel input during a wheel motion adds to the previous target, not to
  `pixels`; otherwise fast notches restart short of where the last one aimed.
- "During a wheel motion" means `activity` is a `_WheelMotionActivity`. Every
  motion, curve included, runs in that one activity rather than `animateTo`,
  so an `animateTo` started elsewhere is never mistaken for ours.
- `Scrollable` decides whether to claim a wheel event from `pixels`, not from
  our target. So `pointerScroll` is still called after the target is clamped at
  an extent, and must return without touching the motion.
- That event has already been claimed, so the enclosing scroll view that
  Flutter would have given it to never sees it. `_passToAncestor` gives it
  there by repeating `Scrollable`'s claim decision on each enclosing
  `ScrollableState`: under the pointer, same axis,
  `physics.shouldAcceptUserOffset`, and a clamped target that differs from
  `pixels`, with the delta's sign converted through both axis directions.
  This copies private SDK logic, so a change there can make the two disagree.
  Chosen by the maintainer in #7 over documenting it as a limitation or asking
  Flutter for a hook; theirs to reverse.
- "Under the pointer" is a render-tree ancestor of the inner view. The
  resolver offers an event only to what was hit-tested, and hit testing walks
  the render tree; the element tree also runs through an `OverlayPortal` (a
  menu, an autocomplete list), so an element ancestor behind a popup would
  otherwise scroll where Flutter leaves it alone. Derived from the SDK, not a
  judgement: a closer reading of hit testing may replace it.
- Only the whole delta is passed, and only when the target is already at the
  extent. A delta that reaches the extent part way loses the rest, as with
  `ScrollController`. Also the maintainer's call in #7.
- The walk uses `findAncestorStateOfType`, not `Scrollable.maybeOf`, which
  registers an inherited dependency on the enclosing scope as a side effect.
- An enclosing smooth position that is itself aiming at its extent passes the
  delta further out the same way, so no loop over several levels is needed.
- The position sets `userScrollDirection` itself, as the default
  `pointerScroll` does; nothing else in a wheel motion would.
- `motion` is read on every wheel input; a zero duration or time constant
  falls back to the default jump.
- A new target replaces the `_Follower`, started from the old one's position
  and velocity. A spring uses that velocity, which is what keeps consecutive
  notches from surging; a curve restarts from rest; a lerp's speed follows the
  remaining distance, so it rises when the target moves away. Only the spring
  is continuous in velocity, by design of the other two.
- The activity clamps to the extents itself. `setPixels` reporting overscroll
  only stops a spring with bounce under clamping physics; bouncing physics
  (the macOS and iOS default) accepts the overscroll and reports none.
- Items stay tappable during every motion (`shouldIgnorePointer` is false),
  unlike `DrivenScrollActivity`. Browsers' smooth scrolling behaves this way,
  and the choice is one getter to reverse.
- Arriving is settling within 0.5 px and 10 px/s, then snapping to the target.
  Both are chosen, not measured: 0.5 px is under a pixel, so the snap is not
  visible, and 10 px/s moves under 0.2 px in a 60 Hz frame.
- Spring parameters are exposed as duration and bounce, not stiffness and
  damping: chosen by hand in the #3 prototype (`prototype/3-wheel-motion`),
  where the physical pair gave no basis for picking a default.

## Code

- `lib/src/smooth_scroll_controller.dart` — `SmoothScrollController`, `_SmoothScrollPosition.pointerScroll`, `_SmoothScrollPosition._passToAncestor`, `_WheelMotionActivity`, `_Follower`, `_SpringFollower`, `_CurveFollower`, `_LerpFollower`
- `lib/src/wheel_motion.dart` — `WheelMotion`, `SpringWheelMotion`, `CurveWheelMotion`, `LerpWheelMotion`

## Reference behaviour

Checked against Flutter `00b0c91f06` (the revision in `.metadata`):

- `packages/flutter/lib/src/widgets/scroll_position_with_single_context.dart` —
  `pointerScroll`, `beginActivity`: the default jump being replaced, and when
  the scroll direction is reset to idle.
- `packages/flutter/lib/src/widgets/scrollable.dart` — `_receivedPointerSignal`,
  `_handlePointerScroll`: the claim decision made from `pixels`, which
  `_passToAncestor` repeats; identical at 3.32.0 and 3.41.9.
- `packages/flutter/lib/src/widgets/scroll_activity.dart` —
  `DrivenScrollActivity`: the end-of-motion and overscroll handling the motion
  activity mirrors, and the pointer-ignoring it does not.
- `packages/flutter/lib/src/physics/spring_simulation.dart` —
  `SpringDescription.withDurationAndBounce`: the duration/bounce mapping.

## Cross-cutting invariants

- [SDK floor](../invariant/sdk-floor.md) — the Flutter version this code may
  assume.

## Blast radius

- [Wheel scale](wheel-scale.md) — supplies the delta this animates.

## Known holes / open

- `NestedScrollView` routes wheel input through
  `_NestedScrollCoordinator.pointerScroll` and is not smoothed.
- A scrollbar with its own controller receives wheel input over its own area,
  which is not smoothed. `flutter_table_plus` and `flutter_folderview` both
  have one; their follow-up issues are not filed yet.
- A custom `Listener` between the two views that registers with
  `pointerSignalResolver` would win the event under Flutter, but a passed
  delta skips it. Measured in #7: with a plain inner list the listener takes
  the notch and the outer list stays at 0; with a smooth one the listener gets
  nothing and the outer list moves 60. Not fixable here: the resolver keeps only
  the first callback, and stopping at any `onPointerSignal` listener would stop
  at the `Scrollbar` desktop wraps around every scroll view. In the framework
  only `Scrollable` and `RawScrollbar` (over its track) register. No test.
- A passed delta was converted with the inner view's
  `ScrollBehavior.pointerAxisModifiers`. An enclosing view under a different
  `ScrollConfiguration` would have read the other axis of the event while
  Shift is held. Not reproduced; no test.
- The activity owns the position it last set. If something else changes
  `pixels` mid-motion (a correction from content resizing above), the next
  frame sets the follower's own value back. Not reproduced; no test.
