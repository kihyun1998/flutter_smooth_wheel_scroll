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

- `lib/src/smooth_scroll_controller.dart` — `SmoothScrollController`, `_SmoothScrollPosition.pointerScroll`, `_WheelMotionActivity`, `_Follower`, `_SpringFollower`, `_CurveFollower`, `_LerpFollower`
- `lib/src/wheel_motion.dart` — `WheelMotion`, `SpringWheelMotion`, `CurveWheelMotion`, `LerpWheelMotion`

## Reference behaviour

Checked against Flutter `00b0c91f06` (the revision in `.metadata`):

- `packages/flutter/lib/src/widgets/scroll_position_with_single_context.dart` —
  `pointerScroll`, `beginActivity`: the default jump being replaced, and when
  the scroll direction is reset to idle.
- `packages/flutter/lib/src/widgets/scrollable.dart` — `_receivedPointerSignal`,
  `_handlePointerScroll`: the claim decision made from `pixels`.
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
- The activity owns the position it last set. If something else changes
  `pixels` mid-motion (a correction from content resizing above), the next
  frame sets the follower's own value back. Not reproduced; no test.
