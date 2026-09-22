# Smooth wheel scroll

## What it is

A `ScrollController` whose positions animate mouse wheel input toward an
accumulated target instead of jumping, by overriding
`ScrollPositionWithSingleContext.pointerScroll`.

## Governing decisions

**None.** Issue #1 specifies it; no decision record exists.

## Design model

- Wheel input during a wheel animation adds to the previous target, not to
  `pixels`; otherwise fast notches restart short of where the last one aimed.
- "During a wheel animation" means `activity` is the very activity this
  position started for wheel input. An `animateTo` started elsewhere is also a
  `DrivenScrollActivity`, and its target is not ours.
- `Scrollable` decides whether to claim a wheel event from `pixels`, not from
  our target. So `pointerScroll` is still called after the target is clamped at
  an extent, and must return without restarting the animation.
- `animateTo` leaves `userScrollDirection` alone, so the position sets it
  after the animation starts, as the default `pointerScroll` does.
- `duration` and `curve` are read on every wheel input; `Duration.zero` falls
  back to the default jump.

## Code

- `lib/src/smooth_scroll_controller.dart` — `SmoothScrollController`, `_SmoothScrollPosition.pointerScroll`

## Reference behaviour

Checked against Flutter `00b0c91f06` (the revision in `.metadata`):

- `packages/flutter/lib/src/widgets/scroll_position_with_single_context.dart` —
  `pointerScroll`, `animateTo`, `beginActivity`: the default jump being
  replaced, and when the scroll direction is reset to idle.
- `packages/flutter/lib/src/widgets/scrollable.dart` — `_receivedPointerSignal`,
  `_handlePointerScroll`: the claim decision made from `pixels`.

## Cross-cutting invariants

**None.**

## Blast radius

- [Wheel scale](wheel-scale.md) — supplies the delta this animates.

## Known holes / open

- `NestedScrollView` routes wheel input through
  `_NestedScrollCoordinator.pointerScroll` and is not smoothed.
- A scrollbar with its own controller receives wheel input over its own area,
  which is not smoothed. `flutter_table_plus` and `flutter_folderview` both
  have one; their follow-up issues are not filed yet.
