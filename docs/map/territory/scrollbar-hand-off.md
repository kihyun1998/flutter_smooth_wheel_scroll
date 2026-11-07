# Scrollbar hand-off

## What it is

A `ScrollController`, `ScrollbarController`, for a scrollbar that sits on its
own `Scrollable` beside the scroll view it stands for. Its position gives a
wheel over the scrollbar to the scroll view's position, so the wheel joins that
position's wheel motion, and keeps the scrollbar's end, press and track click
consistent with the view's.

## Governing decisions

Issue #32 and its agent brief. The name `ScrollbarController`, one public
controller taking the body controller, the physics check, the fallback, the
body type and the replaced body were fixed there. Theirs to reverse. The
measurements are the issue's tables, from `flutter_table_plus` and
`flutter_folderview`.

## Design model

- The scrollbar has no wheel motion of its own. Two motions cancel: each
  mirrored `jumpTo` ends the other side's motion, and an echo guard only stops
  the echo. So the wheel goes to the view's position, which owns the one motion.
- `Scrollable` and `RawScrollbar` both decide from the scrollbar position's own
  pixels and extents, and both end in `position.pointerScroll`. One override
  covers both routes.
- `maxScrollExtent` is the view's, falling back to the scrollbar's own while the
  view has none. A scrollbar claims a wheel by its own extents; if its end
  differs from the view's by a pixel or by float error, it claims notches the
  view cannot use or stops claiming notches the view could, and a notch at the
  view's end no longer reaches an enclosing scroll view.
  `ScrollPosition.applyContentDimensions` keeps a stale value within tolerance,
  so only a getter keeps the two equal.
- A wheel ends whatever activity the scrollbar is running (a track click's
  `DrivenScrollActivity`, a fling's ballistic) with `goIdle` before the
  hand-off, as the default `pointerScroll` does. Otherwise that activity's
  mirrored `jumpTo` ends the motion the notch just started.
- `hold` (a press) and `animateTo` (a track click) stop the view's motion first,
  by a `jumpTo` to its current pixels. Otherwise each view tick's mirrored
  `jumpTo` discards the scrollbar's hold, drag or animation.
- The physics asked are the view position's, always. The scrollbar's own physics
  are not asked by this class: a scrollbar on physics that refuse a modifier
  froze a thumb drag held with Ctrl (`flutter_folderview#114`), and
  `shouldAcceptUserOffset` carries no event, so physics cannot refuse the wheel
  alone: the same call decides the thumb press, the track click and `setCanDrag`.
- `Scrollable` and `RawScrollbar` ask the scrollbar's own physics before they
  claim an event, so by the time `pointerScroll` runs the event is claimed. A
  wheel the view refuses therefore calls
  `PointerScrollEvent.respond(allowPlatformDefault: true)` on the event
  `PointerScrollRecord` holds, which is what the resolver sends when nothing
  claims. Once true it stays true, so the `respond(false)` that `Scrollable` sends
  afterwards does not undo it.
- With no client on the view's controller, or a position with no content
  dimensions, the wheel falls to the scrollbar position's default behaviour: no
  exception, no dropped input.
- The view's controller is read through the position's current controller.
  `Scrollable._shouldUpdatePosition` compares only the controller's
  `runtimeType`, so a position survives a swap of one `ScrollbarController` for
  another and would keep the old view. `ScrollController.attach` runs on the new
  controller, and `ScrollbarController.attach` points the position at it.
- A view that is a plain `ScrollController` gets the wheel through its default
  `pointerScroll`, a jump.
- The listeners that mirror the two controllers, and their echo guard, stay with
  the caller. The overrides react to the `jumpTo` those listeners make.

## Code

- `lib/src/scrollbar_controller.dart` — `ScrollbarController`, `_ScrollbarPosition`
- `lib/src/pointer_scroll_record.dart` — `PointerScrollRecord`, shared with `_SmoothScrollPosition`

## Reference behaviour

Read in Flutter 3.47.1 (the local SDK). The issue's measurements were taken at
3.41.9; the tests compare a wheel over the scrollbar with a wheel over the view
alone, not with the issue's numbers:

- `packages/flutter/lib/src/widgets/scrollbar.dart` — `_receivedPointerSignal`,
  `_handlePointerScroll`, `_pointerSignalEventDelta`, `handleTrackTapDown`: the
  claim decision from the scrollbar position's pixels and extents, the end in
  `pointerScroll`, the axis-only delta that ignores `pointerAxisModifiers`, and
  the track click as `moveTo`.
- `packages/flutter/lib/src/widgets/scrollable.dart` — `_shouldUpdatePosition`:
  compares `controller.runtimeType` only.
- `packages/flutter/lib/src/widgets/scroll_position.dart` —
  `applyContentDimensions`: keeps a stale extent within tolerance.
- `packages/flutter/lib/src/gestures/events.dart` — `respond`: once
  `allowPlatformDefault` is true it cannot become false.
- `engine/src/flutter/lib/web_ui/lib/src/engine/pointer_binding.dart` —
  `_handleWheelEvent`: `preventDefault` unless a response allowed the default.
  `_convertWheelEventToPointerData`: a wheel with `ctrlKey` becomes a scale signal
  with no `onRespond`, unless macOS reports a physical Ctrl key held.

Measured in headless Chrome on the web build of a throwaway app, Flutter 3.47.1,
a DOM `WheelEvent` of delta 120 dispatched on `flutter-view`, the view's physics
refusing. `defaultPrevented`:

| Wheel | Over the view | Over the scrollbar, no `respond` | Over the scrollbar |
|---|---|---|---|
| Plain | false | true | false |
| `ctrlKey` | true | true | true |

With physics that accept, every row is true and the wheel over the scrollbar
moves the view by 120. A `ctrlKey` wheel never reaches `pointerScroll` there, so
Flutter web blocks the browser's zoom over the view and the scrollbar alike.

## Cross-cutting invariants

- [SDK floor](../invariant/sdk-floor.md) — the Flutter version this code may
  assume.

## Blast radius

- [Smooth wheel scroll](smooth-wheel-scroll.md) — the position that takes the
  hand-off; a notch it cannot use goes on to an enclosing view through
  `_passToAncestor`.

## Known holes / open

- A wheel the view refuses is still claimed inside Flutter: the resolver keeps
  the scrollbar's registration, so an enclosing scroll view does not get it.
  Measured in a page with physics that refuse on the view: over the scrollbar the
  page stays at 0, over the view it moves 60. `respond` reaches only the platform.
  A `Listener.onPointerSignal` still sees the event, which is how
  `flutter_table_plus` and `flutter_folderview` read Ctrl+wheel for their scale.
- In a full-page web app inside an iframe the engine reads the responses as
  allowed and not handled, so the `respond(false)` from `Scrollable` wins there.
  Read, not run.
- Shift+wheel over a horizontal scrollbar: `RawScrollbar` ignores the axis
  modifier (flutter/flutter#193282, open when last read; its body was not read).
  The consumers handle it with a `Listener`.
- `NestedScrollView` stays unsmoothed.
- Only synthetic events and the local SDK were tried: no real mouse, no running
  desktop app, and not the floor (3.32.0). The web run dispatched synthetic DOM
  wheel events and read `defaultPrevented`; no browser zoom or page scroll was
  watched.
- That `RenderCustomPaint.hitTestChildren` skips its child when the painter hits,
  so only the `RawScrollbar` route runs on Windows and macOS, is a reviewer's
  report quoted in #32, not read here.
